import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/meta.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/storage.dart';
import 'database.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:synchronized/synchronized.dart';

class SembastDatabase implements Database {
  static Logger logger = new Logger("Sembast");
  final bool LOGV = logger.isLoggable(Level.FINEST);

  final DatabaseStorage _storage;
  final SynchronizedLock lock = new SynchronizedLock();

  String get path => _storage.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;

  Meta _meta;
  int get version => _meta.version;

  bool _opened = false;
  DatabaseMode _openMode;

  @override
  Store get mainStore => _mainStore;

  Store _mainStore;
  Map<String, Store> _stores = new Map();

  Iterable<Store> get stores => _stores.values;

  SembastDatabase([this._storage]);

  ///
  /// put a value in the main store
  ///
  @override
  Future put(var value, [var key]) {
    return _mainStore.put(value, key);
  }

  void _clearTxnData() {
// remove temp data in all store
    for (Store store in stores) {
      (store as SembastStore).rollback();
    }
  }

  void rollback() {
    // only valid in a transaction
    if (!isInTransaction) {
      throw new Exception("not in transaction");
    }
    _clearTxnData();
  }

  bool get isInTransaction => lock.inZone;

  SembastTransaction _transaction;

  SembastTransaction get currentTransaction => _transaction;

  @override
  Transaction get transaction => _transaction;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  @override
  Future<T> inTransaction<T>(FutureOr<T> action()) {
    //devPrint("z: ${Zone.current[_zoneRootKey]}");
    //devPrint("z: ${Zone.current[_zoneChildKey]}");

    if (lock.inZone) {
      return lock.synchronized(action);
    }
    // delay first action
    return new Future(() {
      return lock.synchronized(() async {
        // Compatibility add transaction
        _transaction = new SembastTransaction(++_txnId);

        _transactionCleanUp() {
          // Mark transaction complete, ignore error
          _transaction.completer.complete();

          // Compatibility remove transaction
          _transaction = null;
        }

        T actionResult;
        try {
          actionResult = await new Future.sync(action);
          await _commit();
        } catch (e) {
          _clearTxnData();
          _transactionCleanUp();
          rethrow;
        }

        _clearTxnData();

        // the transaction is done
        // need compact?
        if (_storage.supported) {
          if (_needCompact) {
            await compact();
            //print(_exportStat.toJson());
          }
        }

        _transactionCleanUp();

        return actionResult;
      });
    });
  }

  bool setRecordInMemory(Record record) {
    return _recordStore(record).setRecordInMemory(record);
  }

  void loadRecord(Record record) {
    _recordStore(record).loadRecord(record);
  }

  ///
  /// Compact the database (work in progress)
  ///
  Future compact() {
    return lock.synchronized(() async {
      if (_storage.supported) {
        DatabaseStorage tmpStorage = _storage.tmpStorage;
        // new stat with compact + 1
        DatabaseExportStat exportStat = new DatabaseExportStat()
          ..compactCount = _exportStat.compactCount + 1;
        await tmpStorage.delete();
        await tmpStorage.findOrCreate();

        List<String> lines = [];
        _addLine(Map map) {
          String encoded;
          try {
            encoded = JSON.encode(map);
            exportStat.lineCount++;
            lines.add(encoded);
          } catch (e, st) {
            // usefull for debugging...
            print(map);
            print(e);
            print(st);
            rethrow;
          }
        }

        _addLine(_meta.toMap());
        for (Store store in stores) {
          for (Record record in (store as SembastStore).recordMap.values) {
            _addLine((record as SembastRecord).toMap());
          }
        }
        await tmpStorage.appendLines(lines);
        await _storage.tmpRecover();
        /*
        print(_storage.toString());
        await _storage.readLines().forEach((String line) {
          print(line);
        });
        */
        _exportStat = exportStat;
      }
    });
  }

  // future or not
  _commit() async {
    List<Record> txnRecords = [];
    for (Store store in stores) {
      if ((store as SembastStore).txnRecords != null) {
        txnRecords.addAll((store as SembastStore).txnRecords.values);
      }
    }

    // end of commit
    _saveInMemory() {
      for (Record record in txnRecords) {
        bool exists = setRecordInMemory(record);
        // Try to estimated if compact will be needed
        if (_storage.supported) {
          if (exists) {
            _exportStat.obsoleteLineCount++;
          }
          _exportStat.lineCount++;
        }
      }
    }

    if (_storage.supported) {
      if (txnRecords.isNotEmpty) {
        List<String> lines = [];

        // writable record
        for (Record record in txnRecords) {
          Map map = (record as SembastRecord).toMap();
          String encoded;
          try {
            encoded = JSON.encode(map);
            lines.add(encoded);
          } catch (e, st) {
            print(map);
            print(e);
            print(st);
            rethrow;
          }
        }
        await _storage.appendLines(lines);
        _saveInMemory();
      }
    } else {
      _saveInMemory();
    }
  }

  /// clone and fix the store
  Record _cloneAndFix(Record record) {
    Store store = record.store;
    if (store == null) {
      store = mainStore;
    }
    return (record as SembastRecord).clone(store: store);
  }

  ///
  /// Put a record
  ///
  @override
  Future<Record> putRecord(Record record) {
    return inTransaction(() {
      return txnPutRecord(_cloneAndFix(record));
    });
  }

  ///
  /// Get a record by its key
  ///
  Future<Record> getRecord(var key) {
    return mainStore.getRecord(key);
  }

  ///
  /// Get a store record
  ///
  @override
  Future<Record> getStoreRecord(Store store, var key) {
    return store.getRecord(key);
  }

  ///
  /// Put a list or records
  ///
  @override
  Future<List<Record>> putRecords(List<Record> records) {
    return inTransaction(() {
      List<Record> toPut = [];
      for (Record record in records) {
        toPut.add(_cloneAndFix(record));
      }
      return txnPutRecords(toPut);
    });
  }

  ///
  /// find records in the main store
  ///
  Future<List<Record>> findRecords(Finder finder) {
    return mainStore.findRecords(finder);
  }

  @override
  Future<Record> findRecord(Finder finder) {
    return mainStore.findRecord(finder);
  }

  ///
  /// find records in the given [store]
  ///
  @override
  Future<List<Record>> findStoreRecords(Store store, Finder finder) {
    return store.findRecords(finder);
  }

  Record txnPutRecord(Record record) {
    return _recordStore(record).txnPutRecord(record);
  }

  // record must have been clone before
  List<Record> txnPutRecords(List<Record> records) {
    // temp records
    for (Record record in records) {
      txnPutRecord(record);
    }
    return records;
  }

  ///
  /// get a value by key in the main store
  ///
  Future get(var key) {
    return _mainStore.get(key);
  }

  ///
  /// count all records in the main store
  ///
  Future<int> count([Filter filter]) {
    return _mainStore.count(filter);
  }

  ///
  /// delete a record by key in the main store
  ///
  @override
  Future delete(var key) {
    return _mainStore.delete(key);
  }

  ///
  /// delete a [record]
  ///
  @override
  Future deleteRecord(Record record) {
    return record.store.delete(record.key);
  }

  ///
  /// delete a record by key in the main store
  ///
  Future deleteStoreRecord(Store store, var key) {
    return store.delete(key);
  }

  bool _hasRecord(Record record) {
    return _recordStore(record).hasKey(record.key);
  }

  ///
  /// reload
  //
  Future<Database> reOpen(
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    return lock.synchronized(() {
      close();
      // Reuse same open mode unless specified
      return open(
          version: version,
          onVersionChanged: onVersionChanged,
          mode: mode ?? this._openMode);
    });
  }

  void _checkMainStore() {
    if (_mainStore == null) {
      _addStore(null);
    }
  }

  Store _addStore(String storeName) {
    if (storeName == null) {
      return _mainStore = _addStore(dbMainStore);
    } else {
      Store store = new SembastStore(this, storeName);
      _stores[storeName] = store;
      return store;
    }
  }

  ///
  /// find existing store
  ///
  @override
  Store findStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
    }
    return store;
  }

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  @override
  Store getStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
      if (store == null) {
        store = _addStore(storeName);
      }
    }
    return store;
  }

  ///
  /// clear and delete a store
  ///
  @override
  Future deleteStore(String storeName) {
    Store store = findStore(storeName);
    if (store == null) {
      return new Future.value();
    } else {
      return store.clear().then((_) {
        // do not delete main
        if (store != mainStore) {
          _stores.remove(storeName);
        }
      });
    }
  }

  ///
  /// open a database
  ///
  Future<Database> open(
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    // Default mode
    _openMode = mode ??= databaseModeDefault;

    if (_opened) {
      if (path != this.path) {
        throw new DatabaseException.badParam(
            "existing path ${this.path} differ from open path ${path}");
      }
      return new Future.value(this);
    }

    return lock.synchronized(() async {
      Meta meta;

      Future _handleVersionChanged(int oldVersion, int newVersion) async {
        var result;
        if (onVersionChanged != null) {
          result = onVersionChanged(this, oldVersion, newVersion);
        }
        meta = new Meta(newVersion);

        if (_storage.supported) {
          await _storage.appendLine(JSON.encode(meta.toMap()));
          _exportStat.lineCount++;
        }

        return result;
      }

      Future<Database> _openDone() async {
        // make sure mainStore is created
        _checkMainStore();

        // Set current meta
        // so that it is an old value during onVersionChanged
        if (meta == null) {
          meta = new Meta(0);
        }
        if (_meta == null) {
          _meta = meta;
        }

        bool needVersionChanged = false;

        int oldVersion = meta.version;

        if (oldVersion == 0) {
          needVersionChanged = true;

          // Make version 1 by default
          if (version == null) {
            version = 1;
          }
          meta = new Meta(version);
        } else {
          // no specific version requested or same
          if ((version != null) && (version != oldVersion)) {
            needVersionChanged = true;
          }
        }

        // mark it opened
        _opened = true;

        if (needVersionChanged) {
          await _handleVersionChanged(oldVersion, version);
        }
        _meta = meta;
        return this;
      }

      //_path = path;
      Future _findOrCreate() async {
        if (mode == databaseModeExisting) {
          bool found = await _storage.find();
          if (!found) {
            throw new DatabaseException.databaseNotFound(
                "Database (open existing only) ${path} not found");
          }
        } else {
          if (mode == databaseModeEmpty) {
            await _storage.delete();
          }
          await _storage.findOrCreate();
        }
      }

      // create _exportStat
      if (_storage.supported) {
        _exportStat = new DatabaseExportStat();
      }
      await _findOrCreate();
      if (_storage.supported) {
        // empty stores
        _mainStore = null;
        _stores = new Map();
        _checkMainStore();

        _exportStat = new DatabaseExportStat();

        //bool needCompact = false;
        bool corrupted = false;

        await _storage.readLines().forEach((String line) {
          if (!corrupted) {
            _exportStat.lineCount++;

            Map map;

            try {
              // everything is JSON
              map = JSON.decode(line) as Map;
            } on Exception catch (_) {
              if (_openMode == databaseModeNeverFails) {
                corrupted = true;
                return;
              } else {
                rethrow;
              }
            }

            if (Meta.isMapMeta(map)) {
              // meta?
              meta = new Meta.fromMap(map);
            } else if (SembastRecord.isMapRecord(map)) {
              // record?
              Record record = new SembastRecord.fromMap(this, map);
              if (_hasRecord(record)) {
                _exportStat.obsoleteLineCount++;
              }
              loadRecord(record);
            }
          }
        });
        // if corrupted and not even meta
        // delete it
        if (corrupted && meta == null) {
          await _storage.delete();
          await _storage.findOrCreate();
        } else {
          // auto compaction
          // allow for 20% of lost lines
          // make sure _meta is known before compacting
          _meta = meta;
          if (_needCompact || corrupted) {
            await compact();
          }
        }

        return await _openDone();
      } else {
        // ensure main store exists
        // but do not erase previous data
        _checkMainStore();
        meta = _meta;
        return _openDone();
      }
    });
  }

  close() {
    _opened = false;
    //_mainStore = null;
    //_meta = null;
    // return new Future.value();
  }

  Map toJson() {
    Map map = new Map();
    if (path != null) {
      map["path"] = path;
    }
    if (version != null) {
      map["version"] = version;
    }
    if (_stores != null) {
      List stores = [];
      for (Store store in _stores.values) {
        stores.add((store as SembastStore).toJson());
      }
      map["stores"] = stores;
    }
    if (_exportStat != null) {
      map["exportStat"] = _exportStat.toJson();
    }
    return map;
  }

  DatabaseExportStat _exportStat;
  bool get _needCompact {
    return (_exportStat.obsoleteLineCount > 5 &&
        (_exportStat.obsoleteLineCount / _exportStat.lineCount > 0.20));
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class DatabaseExportStat {
  /// number of line in the export
  int lineCount = 0;

  /// number of lines that are obsolete
  int obsoleteLineCount = 0; // line that might have
  /// Number of time it has been compacted since being opened
  int compactCount = 0;

  DatabaseExportStat();

  DatabaseExportStat.fromJson(Map map) {
    if (map["lineCount"] != null) {
      lineCount = map["lineCount"] as int;
    }
    if (map["compactCount"] != null) {
      compactCount = map["compactCount"] as int;
    }
    if (map["obsoleteLineCount"] != null) {
      obsoleteLineCount = map["obsoleteLineCount"] as int;
    }
  }
  Map toJson() {
    Map map = new Map();
    if (lineCount != null) {
      map["lineCount"] = lineCount;
    }
    if (obsoleteLineCount != null) {
      map["obsoleteLineCount"] = obsoleteLineCount;
    }
    if (compactCount != null) {
      map["compactCount"] = compactCount;
    }
    return map;
  }
}

SembastStore _recordStore(Record record) => record.store as SembastStore;
