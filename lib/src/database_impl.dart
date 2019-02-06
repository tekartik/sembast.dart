import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/meta.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/storage.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:synchronized/synchronized.dart';

import 'database.dart';

class SembastDatabase extends Object
    with DatabaseExecutorMixin
    implements Database {
  final DatabaseOpenHelper openHelper;
  static Logger logger = Logger("Sembast");
  final bool logV = logger.isLoggable(Level.FINEST);

  final DatabaseStorage _storage;
  // Lock used for opening/compacting
  final Lock databaseLock = Lock();
  final Lock transactionLock = Lock();

  @override
  String get path => _storage.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;

  Meta _meta;

  @override
  int get version => _meta.version;

  bool _opened = false;
  DatabaseOpenOptions get _openOptions => openHelper.options;

  // DatabaseMode _openMode;
  // Only set during open (used during onVersionChanged
  Transaction _openTransaction;

  @override
  Store get store => mainStore;

  @override
  Store get mainStore => _mainStore;

  Store _mainStore;
  final Map<String, Store> _stores = {};

  @override
  Iterable<Store> get stores => _stores.values;

  SembastDatabase(this.openHelper, [this._storage]);

  ///
  /// put a value in the main store
  ///
  @override
  Future put(dynamic value, [dynamic key]) {
    return _mainStore.put(value, key);
  }

  @override
  Future update(dynamic value, [dynamic key]) {
    return _mainStore.update(value, key);
  }

  void _clearTxnData() {
// remove temp data in all store
    for (Store store in stores) {
      (store as SembastStore).rollback();
    }
  }

  void txnRollback(SembastTransaction txn) {
    // only valid in a transaction
    if (txn == null) {
      throw Exception("not in transaction");
    }
    _clearTxnData();
  }

  // True if we are currently in the transaction
  // bool get isInTransaction => _isInTransaction;

  SembastTransaction _transaction;

  /// Exported for testing
  SembastTransaction get currentTransaction => _transaction;

  SembastStore _recordStore(Record record) =>
      (record.store ?? mainStore) as SembastStore;

  bool setRecordInMemory(Record record) {
    return _recordStore(record).setRecordInMemory(record);
  }

  void loadRecord(Record record) {
    _recordStore(record).loadRecord(record);
  }

  Future compact() async {
    return databaseLock.synchronized(() {
      return txnCompact();
    });
  }

  ///
  /// Compact the database (work in progress)
  ///
  Future txnCompact() async {
    assert(databaseLock.inLock);
    if (_storage.supported) {
      DatabaseStorage tmpStorage = _storage.tmpStorage;
      // new stat with compact + 1
      DatabaseExportStat exportStat = DatabaseExportStat()
        ..compactCount = _exportStat.compactCount + 1;
      await tmpStorage.delete();
      await tmpStorage.findOrCreate();

      List<String> lines = [];
      void _addLine(Map map) {
        String encoded;
        try {
          encoded = json.encode(map);
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
  }

  // future or not
  Future _commit() async {
    List<Record> txnRecords = [];
    for (Store store in stores) {
      if ((store as SembastStore).txnRecords != null) {
        txnRecords.addAll((store as SembastStore).txnRecords.values);
      }
    }

    // end of commit
    void _saveInMemory() {
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
            encoded = json.encode(map);
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
    return transaction((txn) {
      return cloneRecord(
          txnPutRecord(txn as SembastTransaction, _cloneAndFix(record)));
    });
  }

  ///
  /// Get a record by its key
  ///
  @override
  Future<Record> getRecord(var key) {
    return mainStore.getRecord(key);
  }

  ///
  /// Put a list or records
  ///
  @override
  Future<List<Record>> putRecords(List<Record> records) {
    return transaction((txn) {
      return cloneRecords(txnPutRecords(txn as SembastTransaction, records));
    });
  }

  // in transaction
  List<Record> txnPutRecords(SembastTransaction txn, List<Record> records) {
    return records.map((Record record) {
      return txnPutRecord(txn, _cloneAndFix(record));
    }).toList();
  }

  ///
  /// find records in the main store
  ///
  @override
  Future<List<Record>> findRecords(Finder finder) {
    return mainStore.findRecords(finder);
  }

  @override
  Future<Record> findRecord(Finder finder) {
    return mainStore.findRecord(finder);
  }

  Record txnPutRecord(SembastTransaction txn, Record record) {
    return _recordStore(record).txnPutRecord(txn, record);
  }

  ///
  /// get a value by key in the main store
  ///
  @override
  Future get(var key) {
    return _mainStore.get(key);
  }

  ///
  /// count all records in the main store
  ///
  @override
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

  bool _noTxnHasRecord(Record record) {
    return _recordStore(record).txnContainsKey(null, record.key);
  }

  ///
  /// reload
  //
  Future<Database> reOpen([DatabaseOpenOptions options]) async {
    await close();
    // Reuse same open mode unless specified
    return open(options ?? _openOptions);
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
      Store store = SembastStore(this, storeName);
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

  SembastTransactionStore txnFindStore(
      SembastTransaction txn, String storeName) {
    var store = findStore(storeName);
    return txn.toExecutor(store);
  }

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  @override
  Store getStore(String storeName) {
    var store = findStore(storeName);
    if (store == null) {
      store = _addStore(storeName);
    }
    return store;
  }

  SembastTransactionStore txnGetStore(
      SembastTransaction txn, String storeName) {
    var store = getStore(storeName);
    return txn.toExecutor(store);
  }

  ///
  /// clear and delete a store
  ///
  @override
  Future deleteStore(String storeName) {
    return transaction((txn) {
      txnDeleteStore(txn as SembastTransaction, storeName);
    });
  }

  void txnDeleteStore(SembastTransaction txn, String storeName) {
    var store = txnFindStore(txn, storeName);
    if (store != null) {
      store.store.txnClear(txn);
      // do not delete main
      if (store.store != mainStore) {
        _stores.remove(storeName);
      }
    }
  }

  ///
  /// open a database
  ///
  Future<Database> open(DatabaseOpenOptions options) {
    // Default mode
    var mode = options.mode ?? DatabaseMode.defaultMode;
    int version = options.version;
    var _openMode = mode;

    if (_opened) {
      if (path != this.path) {
        throw DatabaseException.badParam(
            "existing path ${this.path} differ from open path ${path}");
      }
      return Future.value(this);
    }

    return databaseLock.synchronized(() async {
      Meta meta;

      Future _handleVersionChanged(int oldVersion, int newVersion) async {
        var result;
        await transaction((txn) async {
          try {
            // create a transaction during open
            _openTransaction = txn;

            if (options.onVersionChanged != null) {
              result = options.onVersionChanged(this, oldVersion, newVersion);
            }
            meta = Meta(
                version: newVersion, codecSignature: options.codec?.signature);

            if (_storage.supported) {
              await _storage.appendLine(json.encode(meta.toMap()));
              _exportStat.lineCount++;
            }
          } finally {
            _openTransaction = null;
          }
        });

        return result;
      }

      Future<Database> _openDone() async {
        // make sure mainStore is created
        _checkMainStore();

        // Set current meta
        // so that it is an old value during onVersionChanged
        if (meta == null) {
          meta = Meta(version: 0, codecSignature: options.codec?.signature);
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
          meta =
              Meta(version: version, codecSignature: options.codec?.signature);
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
        if (mode == DatabaseMode.existing) {
          bool found = await _storage.find();
          if (!found) {
            throw DatabaseException.databaseNotFound(
                "Database (open existing only) ${path} not found");
          }
        } else {
          if (mode == DatabaseMode.empty) {
            await _storage.delete();
          }
          await _storage.findOrCreate();
        }
      }

      // create _exportStat
      if (_storage.supported) {
        _exportStat = DatabaseExportStat();
      }
      await _findOrCreate();
      if (_storage.supported) {
        // empty stores and meta
        _meta = null;
        _mainStore = null;
        _stores.clear();
        _checkMainStore();

        _exportStat = DatabaseExportStat();

        //bool needCompact = false;
        bool corrupted = false;

        await _storage.readLines().forEach((String line) {
          if (!corrupted) {
            _exportStat.lineCount++;

            Map map;

            try {
              // everything is JSON
              map = json.decode(line) as Map;
            } on Exception catch (_) {
              if (_openMode == DatabaseMode.neverFails) {
                corrupted = true;
                return;
              } else {
                rethrow;
              }
            }

            if (Meta.isMapMeta(map)) {
              // meta?
              meta = Meta.fromMap(map);

              // Check codec signature if any
              if (options.codec?.signature != meta.codecSignature) {
                if (_openMode == DatabaseMode.neverFails) {
                  corrupted = true;
                  return;
                } else {
                  throw DatabaseException.badParam('Invalid codec signature');
                }
              }
            } else if (SembastRecord.isMapRecord(map)) {
              // record?
              Record record = SembastRecord.fromMap(this, map);
              if (_noTxnHasRecord(record)) {
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
            await txnCompact();
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

  void _close() async {
    _opened = false;
    //_meta = null;
    // return new Future.value();
  }

  @override
  Future close() async {
    _close();
    await openHelper.closeDatabase(this);
  }

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
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

  @override
  Future<bool> containsKey(key) => _mainStore.containsKey(key);

  @override
  Future<T> transaction<T>(
      FutureOr<T> Function(Transaction transaction) action) async {
    // during open?
    if (_openTransaction != null) {
      return await action(_openTransaction);
    }
    return transactionLock.synchronized(() async {
      _transaction = SembastTransaction(this, ++_txnId);

      void _transactionCleanUp() {
        // Mark transaction complete, ignore error
        _transaction.completer.complete();

        // Compatibility remove transaction
        _transaction = null;
      }

      T actionResult;
      try {
        actionResult = await Future<T>.sync(() => action(_transaction));
        await _commit();
      } catch (e) {
        _clearTxnData();
        _transactionCleanUp();
        rethrow;
      }

      _clearTxnData();

      _transactionCleanUp();

      return actionResult;
    }).whenComplete(() async {
      // the transaction is done
      // need compact?
      if (_storage.supported) {
        if (_needCompact) {
          await databaseLock.synchronized(() async {
            await txnCompact();
            //print(_exportStat.toJson());
          });
        }
      }
    });
  }

  @override
  SembastDatabase get database => this;

  @override
  Future clear() => mainStore.clear();
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

  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
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
