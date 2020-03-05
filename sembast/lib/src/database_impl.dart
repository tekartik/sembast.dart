import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/env_utils.dart';
import 'package:sembast/src/jdb.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/meta.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/record_impl.dart' as record_impl;
import 'package:sembast/src/sembast_codec_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/sembast_jdb.dart';
import 'package:sembast/src/storage.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:synchronized/synchronized.dart';
import 'package:sembast/src/api/compat/sembast.dart';
// ignore_for_file: deprecated_member_use_from_same_package

final bool _debugStorage = false; // devWarning(true);

/// Get implementation.
SembastDatabase getDatabase(v2.Database database) =>
    database as SembastDatabase;

/// Commit entries in a transaction.
class CommitEntries {
  /// Last known revision
  int revision;

  /// records changed.
  List<TxnRecord> txnRecords;

  /// True when upgrading
  bool upgrading;

  /// Upgrading meta
  Meta upgradingMeta;

  /// Has at least one record
  bool get hasWriteData => txnRecords?.isNotEmpty ?? false;
}

/// Commit database information.
class CommitData extends CommitEntries {
  // Only when we have listeners
  /// listeners.
  List<StoreListenerOperation> listenerOperations;
}

/// Database implementation.
class SembastDatabase extends Object
    with DatabaseExecutorMixin
    implements Database, SembastDatabaseClient {
  // Can be modified by openHelper for test purpose
  /// its open helper.
  DatabaseOpenHelper openHelper;

  /// log helper.
  final bool logV = sembastLogLevel == SembastLogLevel.verbose;

  final StorageBase _storageBase;

  DatabaseStorage _storage;
  StorageJdb _storageJdb;
  StreamSubscription<int> _storageJdbRevisionUpdateSubscription;
  int _jdbRevision;

  /// Get internal jdb storage if any
  StorageJdb get storageJdb => _storageJdb;

  // Lock used for opening/writing/compacting

  /// General lock.
  final Lock databaseLock = Lock();

  /// Transactinon lock.
  final Lock transactionLock = Lock();

  /// Notification lock.
  final Lock notificationLock = Lock();

  /// Created after opening the database
  DatabaseListener listener;

  @override
  String get path => _storageBase.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;

  Meta _meta;

  @override
  int get version => _meta.version;

  // True during onVersionChanged
  bool _upgrading = false;
  Meta _upgradingMeta;
  bool _opened = false;
  bool _closed = false;

  /// The open options.
  DatabaseOpenOptions get openOptions => openHelper.options;

  // DatabaseMode _openMode;
  // Only set during open (used during onVersionChanged
  Transaction _openTransaction;

  @override
  Store get store => mainStore;

  @override
  Store get mainStore => _mainStore;

  Store _mainStore;
  final Map<String, Store> _stores = {};
  final List<String> _txnDroppedStores = [];

  /// Current in memory stores
  Iterable<Store> get stores => _stores.values;

  /// Current in memory store names
  Iterable<String> get storeNames => _stores.values.map((store) => store.name);

  /// Database implementation.
  SembastDatabase(this.openHelper, [this._storageBase]) {
    if (_storageBase is DatabaseStorage) {
      _storage = _storageBase as DatabaseStorage;
    } else if (_storageBase is StorageJdb) {
      _storageJdb = _storageBase as StorageJdb;
    }
  }

  ///
  /// put a value in the main store
  ///
  @override
  Future put(dynamic value, [dynamic key]) {
    return (_mainStore as SembastStore).put(value, key);
  }

  @override
  Future update(dynamic value, [dynamic key]) {
    return _mainStore.update(value, key);
  }

  void _clearTxnData() {
    _txnDroppedStores.clear();

// remove temp data in all store
    for (var store in stores) {
      (store as SembastStore).rollback();
    }
  }

  /// Rollback changed in a transaction.
  void txnRollback(SembastTransaction txn) {
    // only valid in a transaction
    if (txn == null) {
      throw Exception('not in transaction');
    }
    _clearTxnData();
  }

  // True if we are currently in the transaction
  // bool get isInTransaction => _isInTransaction;

  SembastTransaction _transaction;

  /// Exported for testing
  SembastTransaction get currentTransaction => _transaction;

  SembastStore _recordStore(Record record) => getSembastStore(record.ref.store);

//      (record.store ?? mainStore) as SembastStore;

  /// Set in memory.
  bool setRecordInMemory(TxnRecord record) {
    return _recordStore(record).setRecordInMemory(record?.record);
  }

  /// Load a record if needed (delta).
  ///
  /// An old record (lower revision) won't be loaded
  bool jdbDeltaLoadRecord(ImmutableSembastRecordJdb record) {
    var store = _recordStore(record);
    dynamic existing = store.txnGetImmutableRecordSync(null, record.key);
    if (existing is ImmutableSembastRecordJdb) {
      if (existing != null) {
        // devPrint('existing ${existing?.revision} vs new ${record.revision}');
        if (existing.revision != null) {
          if ((record.revision ?? 0) > existing.revision) {
            loadRecord(record);
            return true;
          }
        }
        return false;
      }
    }
    loadRecord(record);
    return true;
  }

  /// Load a record.
  void loadRecord(ImmutableSembastRecord record) {
    _recordStore(record).loadRecord(record);
  }

  /// Compact the database.
  Future compact() async {
    await databaseOperation(() {
      return txnCompact();
    });
  }

  /// Encode a map before writing it to disk
  String encodeMap(Map<String, dynamic> map) {
    if (openOptions.codec != null) {
      return openOptions.codec.codec.encode(map);
    } else {
      return json.encode(map);
    }
  }

  /// Decode a text.
  Map<String, dynamic> decodeString(String text) {
    if (openOptions.codec != null) {
      return openOptions.codec.codec.decode(text);
    } else {
      return (json.decode(text) as Map)?.cast<String, dynamic>();
    }
  }

  /// Get the list of current store that can be safely iterate even
  /// in an async way.
  List<SembastStore> getCurrentStores() => List<SembastStore>.from(stores);

  /// Get the list of current records that can be safely iterate even
  /// in an async way.
  List<ImmutableSembastRecord> getCurrentRecords(Store store) =>
      (store as SembastStore).currentRecords;

  /// For jdb only
  Future<int> generateUniqueIntKey(String store) {
    if (_storageJdb != null) {
      return _storageJdb.generateUniqueIntKey(store);
    }
    return null;
  }

  /// For jdb only
  Future<String> generateUniqueStringKey(String store) {
    if (_storageJdb != null) {
      return _storageJdb.generateUniqueStringKey(store);
    }
    return null;
  }

  ///
  /// Compact the database
  ///
  Future txnCompact() async {
    assert(databaseLock.inLock);
    if (_storage?.supported ?? false) {
      final tmpStorage = _storage.tmpStorage;
      // new stat with compact + 1
      final exportStat = DatabaseExportStat()
        ..compactCount = _exportStat.compactCount + 1;
      await tmpStorage.delete();
      await tmpStorage.findOrCreate();

      final lines = <String>[];

      Future _addStringLine(String line) async {
        await cooperate();
        exportStat.lineCount++;
        if (_debugStorage) {
          print('tmp: $line');
        }
        lines.add(line);
      }

      Future _addLine(Map<String, dynamic> map) async {
        String encoded;
        try {
          encoded = encodeMap(map);
          await _addStringLine(encoded);
        } catch (e, st) {
          // useful for debugging...
          print(map);
          print(e);
          print(st);
          rethrow;
        }
      }

      // meta is always json
      await _addStringLine(json.encode(_meta.toMap()));

      var stores = getCurrentStores();
      for (Store store in stores) {
        final records = getCurrentRecords(store);
        for (var record in records) {
          await _addLine(record.toDatabaseRowMap());
        }
      }
      await tmpStorage.appendLines(lines);
      await _storage.tmpRecover();

      _exportStat = exportStat;
      // devPrint('compacted: $_exportStat');
    } else if (_storageJdb?.supported ?? false) {
      await _storageJdb.compact();
    }
  }

  /// current transaction commit entries
  CommitEntries _txnBuildCommitEntries() {
    final txnRecords = <TxnRecord>[];

    var stores = getCurrentStores();
    for (var store in stores) {
      var records = store.currentTxnRecords;

      if (records?.isNotEmpty ?? false) {
        txnRecords.addAll(records);
      }
    }

    var commitEntries = CommitEntries()
      ..txnRecords = txnRecords
      ..upgrading = _upgrading
      ..upgradingMeta = _upgradingMeta
      ..revision = _jdbRevision;

    return commitEntries;
  }

  TxnDatabaseContent _getTxnDatabaseContent() {
    var content = TxnDatabaseContent();
    for (var store in stores) {
      var records = (store as SembastStore).currentTxnRecords;
      if (records?.isNotEmpty ?? false) {
        content.addStoreRecords(store.ref, records);
      }
    }
    return content;
  }

  /// Save all records to fix in memory.
  ///
  /// Prepare the records for listeners and returns a list of listener operations.
  ///
  /// and commit on storage later...
  CommitData commitInMemory() {
    final txnRecords = <TxnRecord>[];
    var listenerOperations = <StoreListenerOperation>[];

    var content = _getTxnDatabaseContent();
    for (var storeContent in content.stores) {
      var records = storeContent.records;
      var store = storeContent.store;

      if (records?.isNotEmpty == true) {
        // Prepare listener operations
        if (listener.isNotEmpty) {
          var listener = this.listener.getStore(store);
          if (listener != null) {
            listenerOperations
                .add(StoreListenerOperation(listener, storeContent));
          }
        }
      }
    }

    txnRecords.addAll(content._records);

    var commitData = CommitData()
      ..listenerOperations = listenerOperations
      ..txnRecords = txnRecords;
    // Not record, no commit
    if (txnRecords.isNotEmpty) {
      void _saveInMemory() {
        for (var record in txnRecords) {
          final exists = setRecordInMemory(record);
          // Try to estimated if compact will be needed
          if (_storage?.supported ?? false) {
            if (exists) {
              _exportStat.obsoleteLineCount++;
            }
            _exportStat.lineCount++;
          }
        }
      }

      _saveInMemory();
    }

    // Remove dropped store
    if (_txnDroppedStores.isNotEmpty) {
      for (var store in _txnDroppedStores) {
        _stores.remove(store);
      }
    }

    return commitData;
  }

  /// Commit changes to storage.
  Future storageCommitRecords(List<TxnRecord> txnRecords) async {
    if (txnRecords.isNotEmpty) {
      final lines = <String>[];

      if (_storage != null) {
        // writable record
        for (var record in txnRecords) {
          var map = record.record.toDatabaseRowMap();
          String encoded;
          try {
            encoded = encodeMap(map);
            if (_debugStorage) {
              print('add: $encoded');
            }
            lines.add(encoded);
          } catch (e, st) {
            print(map);
            print(e);
            print(st);
            rethrow;
          }
        }
        await _storage.appendLines(lines);
      }
    }
  }

  /// cooperate safe
  Record makeOutRecord(ImmutableSembastRecord record) =>
      record_impl.makeLazyMutableRecord(_recordStore(record), record);

  /// cooperate safe
  Future<List<Record>> makeOutRecords(
      List<ImmutableSembastRecord> records) async {
    if (records != null) {
      var clones = <Record>[];
      // make it safe for the loop
      records = List<ImmutableSembastRecord>.from(records, growable: false);
      for (var record in records) {
        if (needCooperate) {
          await cooperate();
        }
        clones.add(makeOutRecord(record));
      }
      return clones;
    }
    return null;
  }

  /// Put records in a transaction
  Future<List<ImmutableSembastRecord>> txnPutRecords(
      SembastTransaction txn, List<Record> records) async {
    // clone for safe loop
    records = List<Record>.from(records);
    var recordsResult = List<ImmutableSembastRecord>(records.length);
    for (var i = 0; i < records.length; i++) {
      recordsResult[i] = await txnPutRecord(txn, records[i]);
    }
    return recordsResult;
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

  /// Put a record in a transaction.
  Future<ImmutableSembastRecord> txnPutRecord(
      SembastTransaction txn, Record record) {
    return _recordStore(record).txnPutRecord(txn, record);
  }

  ///
  /// get a value by key in the main store
  ///
  @override
  Future get(var key) {
    return (_mainStore as SembastStore).get(key);
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
  /// delete a record by key in the main store
  ///
  Future deleteStoreRecord(Store store, var key) {
    return store.delete(key);
  }

  /// Check if a record is present
  bool _noTxnHasRecord(Record record) {
    return _recordStore(record).txnContainsKey(null, record.key);
  }

  ///
  /// reload
  //
  Future<Database> reOpen([DatabaseOpenOptions options]) async {
    options ??= openOptions;
    await close();
    if (_storageJdb != null) {
      return openHelper.factory.openDatabase(path,
          version: options.version,
          onVersionChanged: options.onVersionChanged,
          codec: options.codec,
          mode: options.mode);
    }
    // Reuse same open mode unless specified
    return open(options);
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
  Store findStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
    }
    return store;
  }

  /// Find a store in a transaction.
  SembastTransactionStore txnFindStore(
      SembastTransaction txn, String storeName) {
    var store = findStore(storeName);
    return txn.toExecutor(store);
  }

  void _checkOpen() {
    if (_closed) {
      throw DatabaseException.closed();
    }
  }

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  Store getStore(String storeName) {
    _checkOpen();
    var store = findStore(storeName);
    store ??= _addStore(storeName);

    return store;
  }

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  @override
  SembastStore getSembastStore(StoreRef ref) {
    _checkOpen();
    var store = findStore(ref.name);
    store ??= _addStore(ref.name);

    return store as SembastStore;
  }

  /// Get a store in a transaction.
  SembastTransactionStore txnGetStore(
      SembastTransaction txn, String storeName) {
    var store = getStore(storeName);
    return txn.toExecutor(store);
  }

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName) {
    return transaction((txn) {
      return txnDeleteStore(txn as SembastTransaction, storeName);
    });
  }

  /// Delete a store in a transaction.
  Future txnDeleteStore(SembastTransaction txn, String storeName) async {
    var store = txnFindStore(txn, storeName);
    if (store != null) {
      await store.store.txnClear(txn);
      // do not delete main
      if (store.store != mainStore) {
        _txnDroppedStores.add(storeName);
      }
    }
  }

  /// Flush changes.
  Future flush() async {
    // Wait for pending transaction
    await transactionLock.synchronized(null);
    // Wait for pending writes
    await databaseOperation(null);
  }

  ///
  /// open a database
  ///
  Future<Database> open(DatabaseOpenOptions options) async {
    // Default mode
    var mode = options.mode ?? DatabaseMode.defaultMode;
    var version = options.version;
    var _openMode = mode;

    if (_opened) {
      return this;
    }

    // Check codec
    if (options.codec != null) {
      if (options.codec.signature == null) {
        throw DatabaseException.invalidCodec('Codec signature cannot be null');
      }
      if (options.codec.codec == null) {
        throw DatabaseException.invalidCodec(
            'Codec implementation cannot be null');
      }
    }

    await databaseLock.synchronized(() async {
      // needed for reOpen
      _closed = false;

      try {
        Meta meta;

        Future _handleVersionChanged(int oldVersion, int newVersion) async {
          _upgrading = true;
          try {
            await transaction((txn) async {
              var result;
              try {
                // create a transaction during open
                _openTransaction = txn;

                meta = _upgradingMeta = Meta(
                    version: newVersion,
                    codecSignature: getCodecEncodedSignature(options.codec));

                // Eventually run onVersionChanged
                // Change will be committed when the transaction terminates
                if (options.onVersionChanged != null) {
                  result = await options.onVersionChanged(
                      this, oldVersion, newVersion);
                }
              } finally {
                _openTransaction = null;
              }
              return result;
            });
          } finally {
            _upgrading = false;
          }
          // Make sure the changes are committed
        }

        Future _openDone() async {
          // make sure mainStore is created
          _checkMainStore();

          // Set current meta
          // so that it is an old value during onVersionChanged
          meta ??= Meta(
              version: 0,
              codecSignature: getCodecEncodedSignature(options.codec));

          _meta ??= meta;

          var needVersionChanged = false;

          final oldVersion = meta.version;

          if (oldVersion == 0) {
            needVersionChanged = true;

            // Make version 1 by default
            version ??= 1;

            meta = Meta(
                version: version,
                codecSignature: getCodecEncodedSignature(options.codec));
          } else {
            // no specific version requested or same
            if ((version != null) && (version != oldVersion)) {
              needVersionChanged = true;
            }
          }

          // mark it opened
          _opened = true;

          // create listener
          listener = DatabaseListener();

          if (needVersionChanged) {
            await _handleVersionChanged(oldVersion, version);
          }
          _meta = meta;
        }

        //_path = path;
        Future _findOrCreate() async {
          if (mode == DatabaseMode.existing) {
            final found = await _storageBase.find();
            if (!found) {
              throw DatabaseException.databaseNotFound(
                  'Database (open existing only) ${path} not found');
            }
          } else {
            if (mode == DatabaseMode.empty) {
              await _storageBase.delete();
            }
            await _storageBase.findOrCreate();
          }
        }

        // create _exportStat
        if (_storageBase?.supported ?? false) {
          _exportStat = DatabaseExportStat();
        }
        await _findOrCreate();
        if (_storageBase.supported) {
          // empty stores and meta
          _meta = null;
          _mainStore = null;
          _stores.clear();
          _checkMainStore();

          if (_storage?.supported ?? false) {
            //bool needCompact = false;
            var corrupted = false;

            var firstLineRead = false;

            await for (var line in _storage.readLines()) {
              _exportStat.lineCount++;

              Map<String, dynamic> map;

              // Until meta is read, we assume it is json
              if (!firstLineRead) {
                // Read the meta first
                // The first line is always json
                try {
                  map = (json.decode(line) as Map)?.cast<String, dynamic>();
                } on Exception catch (_) {}
                if (Meta.isMapMeta(map)) {
                  // meta?
                  meta = Meta.fromMap(map);

                  // Check codec signature if any
                  checkCodecEncodedSignature(
                      options.codec, meta.codecSignature);
                  firstLineRead = true;
                  continue;
                } else {
                  // If a codec is used, we fail
                  if (_openMode == DatabaseMode.neverFails &&
                      options.codec == null) {
                    corrupted = true;
                    break;
                  } else {
                    throw const FormatException('Invalid database format');
                  }
                }
              }

              try {
                // decode record
                map = decodeString(line);
              } on Exception catch (_) {
                // We can have meta here
                try {
                  map = (json.decode(line) as Map)?.cast<String, dynamic>();
                } on Exception catch (_) {
                  if (_openMode == DatabaseMode.neverFails) {
                    corrupted = true;
                    break;
                  } else {
                    rethrow;
                  }
                }
              }

              if (SembastRecord.isMapRecord(map)) {
                // record?
                final record =
                    ImmutableSembastRecord.fromDatabaseRowMap(this, map);
                if (_noTxnHasRecord(record)) {
                  _exportStat.obsoleteLineCount++;
                }
                loadRecord(record);
              } else if (Meta.isMapMeta(map)) {
                // meta?
                meta = Meta.fromMap(map);

                // Check codec signature if any
                checkCodecEncodedSignature(options.codec, meta.codecSignature);
              } else {
                // If a codec is used, we fail
                if (_openMode == DatabaseMode.neverFails &&
                    options.codec == null) {
                  corrupted = true;
                  break;
                } else {
                  throw const FormatException('Invalid database format');
                }
              }
            }
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
              // devPrint('open needCompact $_needCompact corrupted $corrupted $_exportStat');
              if (_needCompact || corrupted) {
                await txnCompact();
              }
            }
          } else if (_storageJdb?.supported ?? false) {
            var map = await _storageJdb.readMeta();

            if (Meta.isMapMeta(map)) {
              // meta?
              meta = Meta.fromMap(map);
            }

            await jdbFullImport();

            /// Revision update to force reading
            _storageJdbRevisionUpdateSubscription =
                _storageJdb.revisionUpdate.listen((revision) {
              jdbDeltaImport(revision);
            });
            _meta = meta;
          }

          return _openDone();
        } else {
          // ensure main store exists
          // but do not erase previous data
          _checkMainStore();
          meta = _meta;
          return _openDone();
        }
      } catch (_) {
        // on failure make sure to close the database
        await lockedClose();
        rethrow;
      }
    });
    await flush();
    return this;
  }

  /// Full import - must be in transaction
  Future jdbFullImport() async {
    /// read revision before.
    _jdbRevision = await _storageJdb.getRevision();
    await for (var entry in _storageJdb.entries) {
      var record = ImmutableSembastRecordJdb(entry.record, entry.value,
          deleted: entry.deleted, revision: entry.id);
      _exportStat.lineCount++;
      // Make it fast
      if (entry.deleted ?? false) {
        _exportStat.obsoleteLineCount++;
      }
      loadRecord(record);
    }
  }

  /// Delta import. Must not be in a transaction
  Future jdbDeltaImport(int revision) async {
    var result = await transaction((txn) async {
      return await txnJdbDeltaImport(revision);
    });

    if (listener.isNotEmpty) {
      if (result.delta && (result.content.isNotEmpty)) {
        /// Prepare listener
        var listenerOperations = <StoreListenerOperation>[];

        result.content.stores.forEach((content) {
          // Prepare listener operations

          var listener = this.listener.getStore(content.store);
          if (listener != null) {
            listenerOperations.add(StoreListenerOperation(listener, content));
          }

          //txnRecords.addAll(records);
        });

        // Notify if needed, done lazily
        // devPrint(listenerOperations);
        if (listenerOperations.isNotEmpty == true) {
          notifyQueryListeners(listenerOperations);
        }
        notifyLazyListeners();
      } else {
        // A full import was done, re-run all queries
        for (var store in listener.stores) {
          var storeListener = listener.getStore(store);
          storeListener.restart();
        }
      }
    }
  }

  /// Delta import. Must be in a transaction
  Future<JdbImportResult> txnJdbDeltaImport(int revision) async {
    // All modifications
    var content = TxnDatabaseContent();
    bool delta;
    var minRevision = _jdbRevision ?? 0;
    var deltaMinRevision = await _storageJdb.getDeltaMinRevision();

    if (minRevision >= deltaMinRevision) {
      delta = true;
      var entries = await _storageJdb.getEntriesAfter(minRevision ?? 0);
      // devPrint('delta import $entries $revision');
      if (!_closed) {
        for (var entry in entries) {
          // skip transaction empry record
          if (entry.record != null) {
            var record = ImmutableSembastRecordJdb(entry.record, entry.value,
                deleted: entry.deleted, revision: entry.id);

            if (jdbDeltaLoadRecord(record)) {
              // Ignore already added/old record
              content.add(record);
            }
          }
        }
        _jdbRevision = revision;
      }
    } else {
      delta = false;
      _exportStat = DatabaseExportStat();
      var records = <ImmutableSembastRecordJdb>[];
      await for (var entry in _storageJdb.entries) {
        var record = ImmutableSembastRecordJdb(entry.record, entry.value,
            deleted: entry.deleted, revision: entry.id);
        _exportStat.lineCount++;
        // Make it fast
        if (entry.deleted ?? false) {
          _exportStat.obsoleteLineCount++;
        }
        records.add(record);
        // Always add
        content.add(record);
      }

      // Synchronous reload
      for (var store in stores) {
        (store as SembastStore).recordMap.clear();
      }
      for (var record in records) {
        loadRecord(record);
      }
    }
    return JdbImportResult(delta: delta, content: content);
  }

  /// To call when in a databaseLock
  Future lockedClose() async {
    _opened = false;
    _closed = true;
    // Close the jdb database
    if (_storageJdb != null) {
      _storageJdb.close();
    }
    await openHelper.lockedCloseDatabase();
  }

  @override
  Future close() async {
    // jdb updates
    // ignore: unawaited_futures
    _storageJdbRevisionUpdateSubscription?.cancel();
    _storageJdbRevisionUpdateSubscription = null;

    return openHelper.lock.synchronized(() async {
      // Cancel listener
      listener.close();
      // Make sure any pending changes are committed
      await flush();

      await lockedClose();
    });
  }

  /// info as json
  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    if (path != null) {
      map['path'] = path;
    }
    if (version != null) {
      map['version'] = version;
    }
    if (_stores != null) {
      final stores = <Map<String, dynamic>>[];
      for (var store in _stores.values) {
        stores.add((store as SembastStore).toJson());
      }
      map['stores'] = stores;
    }
    if (_exportStat != null) {
      map['exportStat'] = _exportStat.toJson();
    }
    return map;
  }

  /// Lazy store operations.
  final lazyStorageOperations = <Future Function()>[];

  /// Lazy listener operations.
  final lazyListenerOperations = <Future Function()>[];

  DatabaseExportStat _exportStat;

  /// Basic algorithm to tell whether the storage file must be updated
  /// (compacted) or not.
  ///
  /// It has to be fast and compacting has a cost so good not to do it too
  /// often.
  ///
  /// As of v1 the rule is following:
  /// * There are at least 6 records
  /// * There are 20% of obsolete lines to delete
  bool get _needCompact {
    return (_storage != null) &&
        (_exportStat.obsoleteLineCount > 5 &&
            (_exportStat.obsoleteLineCount / _exportStat.lineCount > 0.20));
  }

  @override
  String toString() {
    return toJson().toString();
  }

  @override
  Future<bool> containsKey(key) => _mainStore.containsKey(key);

  /// Execute an exclusive operation on the database storage
  Future databaseOperation(Future Function() action) async {
    // Don't lock if no pending operation, nor action
    if (lazyStorageOperations.isEmpty && action == null) {
      return;
    }
    await databaseLock.synchronized(() async {
      if (lazyStorageOperations.isNotEmpty) {
        var list = List.from(lazyStorageOperations);
        // devPrint('operation ${list.length}');
        for (var operation in list) {
          try {
            await operation();
          } catch (e) {
            print('lazy storage err $e');
          }
          lazyStorageOperations.remove(operation);
        }
      }
      if (action != null) {
        await action();
      }
    });
  }

  @override
  Future<T> transaction<T>(
      FutureOr<T> Function(Transaction transaction) action) async {
    // during open?
    if (_openTransaction != null) {
      return await action(_openTransaction);
    }
    CommitData commitData;

    final upgrading = _upgrading;

    /// For jdb only
    var reloadData = false;
    StorageJdbWriteResult jdbIncrementRevisionStatus;
    T result;
    do {
      if (reloadData) {
        await transactionLock.synchronized(() async {
          await txnJdbDeltaImport(jdbIncrementRevisionStatus.revision);
        });
        reloadData = false;
      }
      result = await transactionLock.synchronized(() async {
        _transaction = SembastTransaction(this, ++_txnId);
        // To handle dropped stores

        void _transactionCleanUp() {
          _clearTxnData();
          // Mark transaction complete, ignore error
          _transaction?.completer?.complete();

          // Compatibility remove transaction
          _transaction = null;
        }

        T actionResult;

        try {
          // devPrint('transaction ${jdbRevision}');
          actionResult = await Future<T>.sync(() => action(_transaction));

          // Commit directly on jdb to handle transaction changes
          if (storageJdb != null) {
            var commitEntries = _txnBuildCommitEntries();

            /// Replay the transaction if something has changed
            if (commitEntries.hasWriteData || commitEntries.upgrading) {
              // Build Entries
              var entries = <JdbWriteEntry>[];
              for (var record in commitEntries.txnRecords) {
                var entry = JdbWriteEntry()..txnRecord = record;
                entries.add(entry);
              }
              var query = StorageJdbWriteQuery(
                  revision: commitEntries.revision,
                  entries: entries,
                  infoEntries: upgrading
                      ? [getMetaInfoEntry(commitEntries.upgradingMeta)]
                      : null);

              /// Commit to storage now
              var status = await storageJdb.writeIfRevision(query);
              // devPrint(status);
              if (!status.success) {
                reloadData = true;
                jdbIncrementRevisionStatus = status;
                _transactionCleanUp();
              } else {
                _jdbRevision = status.revision;
              }
            }
          }
          commitData = commitInMemory();
        } catch (e) {
          _transactionCleanUp();
          rethrow;
        } finally {
          // fs storage only
          if (_storage?.supported ?? false) {
            final hasRecords = commitData?.txnRecords?.isNotEmpty == true;

            if (hasRecords || upgrading) {
              Future postTransaction() async {
                // spawn commit if needed
                // storagage commit and compacting is done lazily

                //
                // Write meta when upgrading, write before the records!
                //
                if (upgrading) {
                  await _storage
                      .appendLine(json.encode(_upgradingMeta.toMap()));
                  _exportStat.lineCount++;
                }
                if (commitData?.txnRecords?.isNotEmpty == true) {
                  await storageCommitRecords(commitData.txnRecords);
                }

                // devPrint('needCompact $_needCompact $_exportStat');

                // Check compaction if records were changed only
                // Lazy compact!
                if (!_upgrading && _needCompact) {
                  await txnCompact();
                }
              }

              if (upgrading) {
                await postTransaction();
              } else {
                lazyStorageOperations.add(postTransaction);
              }
            }
          }
        }

        // Notify if needed, done lazily
        if (commitData?.listenerOperations?.isNotEmpty == true) {
          notifyQueryListeners(commitData.listenerOperations);
        }
        _transactionCleanUp();

        return actionResult;
      }).whenComplete(() async {
        notifyLazyListeners();

        if (!upgrading) {
          // trigger lazy operation
          await databaseOperation(null);
        }
      });
    } while (reloadData);
    return result;
  }

  /// Lazily notify listeners
  void notifyLazyListeners() {
    // Notify if needed
    if (lazyListenerOperations.isNotEmpty) {
      // Don't await on purpose here
      // ignore: unawaited_futures
      notificationLock.synchronized(() async {
        if (lazyListenerOperations.isNotEmpty) {
          var list = List.from(lazyListenerOperations);
          // devPrint('listeners ${list.length}');
          for (var operation in list) {
            try {
              await operation();
            } catch (e, st) {
              print('err lazy listeners $e');
              if (isDebug) {
                print(st);
              }
            }
            lazyListenerOperations.remove(operation);
          }
        }
      });
    }
  }

  /// Our cooperator.
  var cooperator = Cooperator();

  /// True if activated.
  bool get cooperateOn => cooperator?.cooperateOn ?? false;

  /// True if cooperate needed.
  bool get needCooperate => cooperateNeeded(cooperator);

  /// Cooperate if needed.
  FutureOr cooperate() => cooperator?.cooperate();

  /// Ensure the transaction is still current
  void checkTransaction(SembastTransaction transaction) {
    if (transaction != null && transaction != currentTransaction) {
      throw StateError(
          'The transaction is no longer active. Make sure you (a)wait all pending operations in your transaction block');
    }
  }

  @override
  SembastDatabase get sembastDatabase => this;

  @override
  Future<T> inTransaction<T>(
          FutureOr<T> Function(SembastTransaction transaction) action) =>
      transaction((txn) => action(txn as SembastTransaction));

  /// records must not changed
  Future forEachRecords(List<ImmutableSembastRecord> records,
      void Function(ImmutableSembastRecord record) action) async {
    // handle record in transaction first
    for (var record in records) {
      // then the regular unless already in transaction
      if (needCooperate) {
        await cooperate();
      }
      action(record);
    }
  }

  // Only set during open
  @override
  SembastTransaction get sembastTransaction =>
      _openTransaction as SembastTransaction;

  /// Notifify queryListeners
  void notifyQueryListeners(List<StoreListenerOperation> listenerOperations,
      {bool full}) {
    if (listenerOperations?.isEmpty ?? true) {
      return;
    }
    full ??= false;

    lazyListenerOperations.add(() async {
      for (var operation in listenerOperations) {
        if (full) {
          if (debugListener) {
            print('full import listeners none');
          }
          /*
          // records, synchronous
          var store = operation.store;
          var keys = operation.listener.recordKeys;
          for (var key in keys) {
            var record = store.record(key);
            var ctlrs = operation.listener.getRecordControllers(record);
            for (var ctlr in ctlrs) {
              ctlr.add(operation.content.record(key));
            }
          }
          // store, async
          // Fix existing queries
          for (var query in List<QueryListenerController>.from(
              operation.listener.getQuery())) {
            Future _updateQuery() async {
              if (debugListener) {
                print('updating $query: with ${operation.content.records}');
              }
              await query.update(operation.content.records, cooperator);
            }

            if (query.hasInitialData) {
              await _updateQuery();
            } else {
              // postpone
              // ignore: unawaited_futures
              notificationLock.synchronized(() async {
                await _updateQuery();
              });
            }
          }
           */

        } else {
          for (var record in operation.content.records) {
            var ctlrs = operation.listener.getRecordControllers(record.ref);
            if (ctlrs != null) {
              for (var ctlr in ctlrs) {
                void _updateRecord() {
                  if (debugListener) {
                    print('updating $ctlr: with ${record}');
                  }
                  if (!record.deleted) {
                    ctlr.add(record);
                  } else {
                    ctlr.add(null);
                  }
                }

                if (ctlr.hasInitialData) {
                  // devPrint('adding $record');
                  _updateRecord();
                } else {
                  // postpone
                  // ignore: unawaited_futures
                  notificationLock.synchronized(() async {
                    _updateRecord();
                  });
                }
              }
            }
          }
          // Fix existing queries
          for (var query in List<QueryListenerController>.from(
              operation.listener.getQuery())) {
            Future _updateQuery() async {
              if (debugListener) {
                print('updating $query: with ${operation.content.records}');
              }
              await query.update(operation.content.records, cooperator);
            }

            if (query.hasInitialData) {
              await _updateQuery();
            } else {
              // postpone
              // ignore: unawaited_futures
              notificationLock.synchronized(() async {
                await _updateQuery();
              });
            }
          }
        }
      }
    });
  }
}

/// Export stat.
class DatabaseExportStat {
  /// number of line in the export
  int lineCount = 0;

  /// number of lines that are obsolete
  int obsoleteLineCount = 0; // line that might have
  /// Number of time it has been compacted since being opened
  int compactCount = 0;

  /// Export stat.
  DatabaseExportStat();

  /// From a map.
  DatabaseExportStat.fromJson(Map map) {
    if (map['lineCount'] != null) {
      lineCount = map['lineCount'] as int;
    }
    if (map['compactCount'] != null) {
      compactCount = map['compactCount'] as int;
    }
    if (map['obsoleteLineCount'] != null) {
      obsoleteLineCount = map['obsoleteLineCount'] as int;
    }
  }

  /// To a map.
  Map<String, dynamic> toJson() {
    var map = <String, dynamic>{};
    if (lineCount != null) {
      map['lineCount'] = lineCount;
    }
    if (obsoleteLineCount != null) {
      map['obsoleteLineCount'] = obsoleteLineCount;
    }
    if (compactCount != null) {
      map['compactCount'] = compactCount;
    }
    return map;
  }

  @override
  String toString() => toJson().toString();
}

/// Store content.
class StoreContent {
  /// Store ref.
  final StoreRef store;

  /// Record with key.
  final _map = <dynamic, ImmutableSembastRecord>{};

  /// Store content.
  StoreContent(this.store);

  /// All records.
  Iterable<ImmutableSembastRecord> get records => _map.values;

  /// Add all records.
  void addAll(Iterable<ImmutableSembastRecord> records) {
    for (var record in records) {
      add(record);
    }
  }

  /// Add a single record.
  void add(ImmutableSembastRecord record) {
    _map[record.key] = record;
  }

  /// Get a single record.
  ImmutableSembastRecord record(key) => _map[key];

  @override
  String toString() => '${store.name} ${records.length}';
}

/// Database content in a transaction.
class TxnDatabaseContent extends DatabaseContent {
  final _records = <TxnRecord>[];

  /// Add a transaction record.
  void addRecord(TxnRecord record) {
    _records.add(record);
    add(record.record);
  }

  /// Add transaction records for a give store
  void addStoreRecords(StoreRef store, Iterable<TxnRecord> records) {
    addStore(store).addAll(records.map((record) => record.record));
    _records.addAll(records);
  }
}

/// Database content.
class DatabaseContent {
  final _map = <StoreRef, StoreContent>{};

  /// true if at least one store.
  bool get isNotEmpty => _map.isNotEmpty;

  /// All stores.
  Iterable<StoreContent> get stores => _map.values;

  /// Add all records.
  void addAll(Iterable<ImmutableSembastRecord> records) {
    for (var record in records) {
      add(record);
    }
  }

  /// Add a single record.
  void add(ImmutableSembastRecord record) {
    var store = record.ref.store;
    var content = addStore(store);
    content.add(record);
  }

  /// Add a store.
  StoreContent addStore(StoreRef store) {
    var content = _map[store] ??= StoreContent(store);
    return content;
  }

  /// A given existing store.
  StoreContent store(StoreRef store) => _map[store];

  @override
  String toString() => '$stores';
}

/// Import result.
class JdbImportResult {
  /// True if delta import.
  final bool delta;

  /// Only for delta import.
  final TxnDatabaseContent content;

  /// Import result.
  JdbImportResult({@required this.delta, this.content});
}
