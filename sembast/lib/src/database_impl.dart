import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/async_content_codec.dart';
import 'package:sembast/src/changes_listener.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_content.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/debug_utils.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/meta.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_codec.dart';
import 'package:sembast/src/sembast_codec_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/storage.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/src/utils.dart';
import 'package:synchronized/synchronized.dart';

import 'api/protected/database.dart';

final bool _debugStorage = false; // devWarning(true);

/// Get implementation.
SembastDatabase getDatabase(Database database) => database as SembastDatabase;

/// Commit entries in a transaction.
class CommitEntries {
  /// Last known revision
  int? revision;

  /// records changed.
  List<TxnRecord>? txnRecords;

  /// True when upgrading
  late bool upgrading;

  /// Upgrading meta
  Meta? upgradingMeta;

  /// Has at least one record
  bool get hasWriteData => txnRecords?.isNotEmpty ?? false;
}

/// Commit database information.
class CommitData extends CommitEntries {
  // Only when we have listeners
}

/// Mixin to help on evolution
@Deprecated('use SembastDatabaseMixin')
typedef SembastDatabaseMin = SembastDatabaseMixin;

/// Mixin to help on evolution (renamed from SembastDatabaseMin
mixin SembastDatabaseMixin implements Database {}

/// Database implementation.
class SembastDatabase extends Object
    with SembastDatabaseMixin
    implements Database, SembastDatabaseClient {
  // Can be modified by openHelper for test purpose
  /// its open helper.
  DatabaseOpenHelper openHelper;

  /// log helper.
  final bool logV = sembastLogLevel == SembastLogLevel.verbose;

  final StorageBase? _storageBase;

  DatabaseStorage? _storageFs;
  StorageJdb? _storageJdb;
  StreamSubscription<int>? _storageJdbRevisionUpdateSubscription;
  int? _jdbRevision;

  /// Get internal jdb storage if any
  StorageJdb? get storageJdb => _storageJdb;

  // Lock used for opening/writing/compacting

  /// General lock.
  final Lock databaseLock = Lock();

  /// Transactinon lock.
  final Lock transactionLock = Lock();

  /// Notification lock.
  final Lock notificationLock = Lock();

  /// Closed/clear on open and close
  final listener = DatabaseListener();

  /// Store change listeners
  final changesListener = DatabaseChangesListener();

  @override
  String get path => _storageBase!.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;

  Meta? _meta;

  @override
  int get version => _meta!.version!;

  // True during onVersionChanged
  bool _upgrading = false;
  Meta? _upgradingMeta;
  bool _opened = false;
  bool _closed = false;

  /// The open options.
  DatabaseOpenOptions get openOptions => openHelper.options;

  // DatabaseMode _openMode;
  // Only set during open (used during onVersionChanged
  Transaction? _openTransaction;

  /// Our main store
  SembastStore? get mainStore => _mainStore;

  SembastStore? _mainStore;
  final _stores = <String, SembastStore>{};
  final _txnDroppedStores = <String>[];

  /// To optimize auto increment int key generation in a transaction
  final Map<String, int?> _txnStoreLastIntKeys = <String, int>{};

  /// Current in memory stores
  Iterable<SembastStore> get stores => _stores.values;

  /// Current in memory store names
  Iterable<String> get storeNames => _stores.values.map((store) => store.name);

  /// Current non empty store names
  Iterable<String> get nonEmptyStoreNames => _stores.values
      .where((store) => !store.isEmpty)
      .map((store) => store.name);

  /// Database implementation.
  SembastDatabase(this.openHelper, [this._storageBase]) {
    if (_storageBase is DatabaseStorage) {
      _storageFs = _storageBase;
    } else if (_storageBase is StorageJdb) {
      _storageJdb = _storageBase;
    }
  }

  void _clearTxnData() {
    _txnDroppedStores.clear();
    _txnStoreLastIntKeys.clear();
    changesListener.txnClearChanges();

    // remove temp data in all store
    for (var store in stores) {
      store.rollback();
    }
  }

  /// Rollback changed in a transaction.
  void txnRollback(SembastTransaction txn) {
    // only valid in a transaction
    _clearTxnData();
  }

  // True if we are currently in the transaction
  // bool get isInTransaction => _isInTransaction;

  SembastTransaction? _transaction;

  /// Exported for testing
  SembastTransaction? get currentTransaction => _transaction;

  SembastStore _recordStore(SembastRecord record) =>
      getSembastStore(record.ref.store);

  //      (record.store ?? mainStore) as SembastStore;

  /// Set in memory.
  bool setRecordInMemory(TxnRecord record) {
    return _recordStore(record).setRecordInMemory(record.record);
  }

  /// Load a record if needed (delta).
  ///
  /// An old record (lower revision) won't be loaded
  bool jdbDeltaLoadRecord(ImmutableSembastRecordJdb record) {
    var store = _recordStore(record);
    dynamic existing = store.txnGetRawImmutableRecordSync(null, record.key);
    if (existing is ImmutableSembastRecordJdb) {
      // devPrint('existing ${existing?.revision} vs new ${record.revision}');
      if (existing.revision != null) {
        if ((record.revision ?? 0) > existing.revision!) {
          loadRecord(record);
          return true;
        }
      }
      return false;
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

  /// Compact the database.
  Future checkForChanges() async {
    if (_storageJdb?.supported ?? false) {
      var revision = await _storageJdb!.getRevision();
      // print('checkForChanges $revision vs existing $_jdbRevision');
      if (revision != _jdbRevision) {
        await transaction((txn) {
          return txnJdbDeltaImport(revision);
        });
      }
    }
  }

  /// Encode a map before writing it to disk
  @Deprecated('use encodeRecordMapAsyncOrSync')
  String encodeRecordMap(Map map) => encodeRecordMapSync(map);

  /// Encode a map before writing it to disk (async codec only)
  Future<String> encodeRecordMapAsync(Map map) =>
      _contentCodec.encodeContentAsync(toJsonEncodable(map) as Map);

  /// Encode a map before writing it to disk
  String encodeRecordMapSync(Map map) =>
      _contentCodec.encode(toJsonEncodable(map));

  /// Encode a record map, handling async codec.
  FutureOr<String> encodeRecordMapAsyncOrSync(Map map) =>
      _contentCodec.encodeContent(toJsonEncodable(map) as Map);

  /// Decode a text.
  @Deprecated('Sync')
  Map? decodeRecordLineString(String text) => decodeRecordLineStringSync(text);

  /// For sync codec.
  Map decodeRecordLineStringSync(String text) {
    var result = fromJsonEncodable(_contentCodec.decodeContentSync(text));
    if (result is Map) {
      return result;
    }
    throw 'Invalid line length ${text.length}';
  }

  /// For async codec.
  Future<Map> decodeRecordLineStringAsync(String text) async {
    var result = fromJsonEncodable(
      await _contentCodec.decodeContentAsync(text),
    );
    if (result is Map) {
      return result;
    }
    throw 'Invalid line length ${text.length}';
  }

  /// Get the list of current store that can be safely iterate even
  /// in an async way.
  List<SembastStore> getCurrentStores() => List<SembastStore>.from(stores);

  /// Get the list of current records that can be safely iterate even
  /// in an async way.
  List<ImmutableSembastRecord> getCurrentRecords(SembastStore store) =>
      store.currentRecords;

  /// For jdb only
  Future<int?> generateUniqueIntKey(String store) async {
    if (_storageJdb != null) {
      // Get any previous generated int key
      var lastIntKey = _txnStoreLastIntKeys[store];
      if (lastIntKey == null) {
        lastIntKey = await _storageJdb!.generateUniqueIntKey(store);
      } else {
        // increment previous read value
        lastIntKey++;
      }
      // Save for laters insert in the same transaction
      _txnStoreLastIntKeys[store] = lastIntKey;

      return lastIntKey;
    }
    return null;
  }

  /// For jdb only
  Future<String?> generateUniqueStringKey(String store) async {
    if (_storageJdb != null) {
      return _storageJdb!.generateUniqueStringKey(store);
    }
    return null;
  }

  ///
  /// Compact the database
  ///
  Future txnCompact() async {
    // Don't compact read only database
    if (isReadOnly) {
      return;
    }
    assert(databaseLock.inLock);
    if (_storageFs?.supported ?? false) {
      final tmpStorage = _storageFs!.tmpStorage!;
      // new stat with compact + 1
      final exportStat =
          DatabaseExportStat()..compactCount = _exportStat!.compactCount + 1;
      await tmpStorage.delete();
      await tmpStorage.findOrCreate();

      /// Write by 5MB chunks
      const maxWriteSize = 5000000;
      var currentWriteSize = 0;
      var sink = await tmpStorage.openAppend();
      try {
        final lines = <String>[];
        Future<void> writeCurrent() async {
          if (currentWriteSize > 0) {
            var linesCopy = List.of(lines);
            lines.clear();
            await sink.appendLines(linesCopy);
            currentWriteSize = 0;
          }
        }

        Future addStringLine(String line) async {
          await cooperate();
          exportStat.lineCount++;
          if (_debugStorage) {
            // ignore: avoid_print
            print('tmp: $line');
          }
          lines.add(line);
          currentWriteSize += line.length;
          if (currentWriteSize > maxWriteSize) {
            await writeCurrent();
          }
        }

        var hasAsyncCodec = _contentCodec.isAsyncCodec;
        Future addLine(Map map) async {
          String encoded;
          try {
            if (hasAsyncCodec) {
              encoded = await encodeRecordMapAsync(map);
            } else {
              encoded = encodeRecordMapSync(map);
            }

            await addStringLine(encoded);
          } catch (e, st) {
            if (_debugStorage) {
              // useful for debugging...
              // ignore: avoid_print
              print(map);
              // ignore: avoid_print
              print(e);
              // ignore: avoid_print
              print(st);
            }
            rethrow;
          }
        }

        // meta is always json
        await addStringLine(json.encode(_meta!.toMap()));

        var stores = getCurrentStores();
        for (var store in stores) {
          final records = getCurrentRecords(store);
          for (var record in records) {
            await addLine(record.toDatabaseRowMap());
          }
        }
        await writeCurrent();
      } finally {
        await sink.close();
      }
      await _storageFs!.tmpRecover();

      _exportStat = exportStat;

      // devPrint('compacted: $_exportStat');
    } else if (_storageJdb?.supported ?? false) {
      await _storageJdb!.compact();
      // Count Not safe but it is just dev stats...
      _exportStat!.compactCount = _exportStat!.compactCount + 1;
    }
  }

  /// current transaction commit entries
  CommitEntries _txnBuildCommitEntries() {
    final txnRecords = <TxnRecord>[];

    var stores = getCurrentStores();
    for (var store in stores) {
      var records = store.currentTxnRecords;

      if (records?.isNotEmpty ?? false) {
        txnRecords.addAll(records!);
      }
    }

    var commitEntries =
        CommitEntries()
          ..txnRecords = txnRecords
          ..upgrading = _upgrading
          ..upgradingMeta = _upgradingMeta
          ..revision = _jdbRevision;

    return commitEntries;
  }

  TxnDatabaseContent _getTxnDatabaseContent() {
    var content = TxnDatabaseContent();
    for (var store in stores) {
      var records = store.currentTxnRecords;
      if (records?.isNotEmpty ?? false) {
        content.addTxnStoreRecords(store.ref, records!);
      }
    }
    return content;
  }

  /// pending content to send to listeners.
  ///
  /// content must be accessed and cleared in a sync way.
  final _pendingListenerContent = DatabaseListenerContent();

  /// Save all records to fix in memory.
  ///
  /// Prepare the records for listeners and returns a list of listener operations.
  ///
  /// and commit on storage later...
  CommitData commitInMemory() {
    //final txnRecords = <TxnRecord>[];

    var content = _getTxnDatabaseContent();

    var txnRecords = content.txnRecords;

    var commitData = CommitData()..txnRecords = txnRecords;
    // Not record, no commit
    if (txnRecords.isNotEmpty) {
      void saveInMemory() {
        if (isReadOnly) {
          throw DatabaseException.badParam('Read-only database');
        }
        for (var record in txnRecords) {
          final exists = setRecordInMemory(record);
          // Try to estimated if compact will be needed
          if (_storageFs?.supported ?? false) {
            if (exists) {
              _exportStat!.obsoleteLineCount++;
            }
            _exportStat!.lineCount++;
          }
        }
      }

      saveInMemory();
    }

    // Remove dropped store
    if (_txnDroppedStores.isNotEmpty) {
      for (var store in _txnDroppedStores) {
        _stores.remove(store);
      }
    }

    // Add changes to listener content, only if listening
    if (listener.isNotEmpty) {
      for (var storeContent in content.stores) {
        var records = storeContent.records;
        var store = storeContent.store;

        if (records.isNotEmpty) {
          // Prepare listener operations

          var listener = this.listener.getStore(store);
          if (listener != null) {
            if (listener.hasStoreListener) {
              var storeListenerContent = _pendingListenerContent.addStore(
                store,
              );
              storeListenerContent.addAll(records);
            } else {
              for (var record in records) {
                if (listener.keyHasRecordListener(record.key)) {
                  _pendingListenerContent.addRecord(record);
                }
              }
            }
          }
        }
      }
    }

    return commitData;
  }

  /// Commit changes to storage.
  Future storageCommitRecords(List<TxnRecord> txnRecords) async {
    if (txnRecords.isNotEmpty) {
      final lines = <String>[];

      if (_storageFs != null) {
        // writable record
        for (var record in txnRecords) {
          var map = record.record.toDatabaseRowMap();
          String encoded;
          try {
            var encodedOrFuture = encodeRecordMapAsyncOrSync(map);
            if (encodedOrFuture is Future) {
              encoded = await encodedOrFuture;
            } else {
              encoded = encodedOrFuture;
            }
            if (_debugStorage) {
              // ignore: avoid_print
              print('add: $encoded');
            }
            lines.add(encoded);
          } catch (e, st) {
            if (_debugStorage) {
              // ignore: avoid_print
              print(map);
              // ignore: avoid_print
              print(e);
              // ignore: avoid_print
              print(st);
            }
            rethrow;
          }
        }
        await _storageFs!.appendLines(lines);
      }
    }
  }

  /// Put records in a transaction
  Future<List<ImmutableSembastRecord?>> txnPutRecords(
    SembastTransaction txn,
    List<ImmutableSembastRecord> records,
  ) async {
    // clone for safe loop
    records = List<ImmutableSembastRecord>.from(records);
    var recordsResult = List<ImmutableSembastRecord?>.filled(
      records.length,
      null,
    );
    for (var i = 0; i < records.length; i++) {
      recordsResult[i] = await txnPutRecord(txn, records[i]);
    }
    return recordsResult;
  }

  /// Put a record in a transaction.
  Future<ImmutableSembastRecord> txnPutRecord(
    SembastTransaction txn,
    ImmutableSembastRecord record,
  ) {
    return _recordStore(record).txnPutRecord(txn, record);
  }

  /// Check if a record is present
  bool _noTxnHasRecord(ImmutableSembastRecord record) {
    return _recordStore(record).txnContainsKey(null, record.key);
  }

  /// True if database is read-only mode
  bool get isReadOnly => openOptions.mode == DatabaseMode.readOnly;
  Future<void> _recreateStorageFs() async {
    if (_storageFs != null && !isReadOnly) {
      await _storageFs!.delete();
      await _storageFs!.findOrCreate();
    }
  }

  /// Reload the database.
  Future<void> reload() async {
    await transaction((txn) async {
      var sembastTxn = txn as SembastTransaction;
      // clear all records in memory
      for (var store in _stores.values) {
        await store.txnClear(sembastTxn);
        // Delete records in memory too
        store.clearRecordMap();
      }
      if (_storageFs?.supported ?? false) {
        var corrupted = false;
        Meta? meta;
        Future import(Stream<String> lines, {bool? safeMode}) async {
          var result = await _fsFullMetaAndImport(
            lines,
            safeMode: safeMode,
            options: openOptions,
          );
          corrupted = result.corrupted;
          meta = result.meta;
        }

        try {
          await import(_storageFs!.readLines(), safeMode: true);
        } catch (e) {
          corrupted = true;
          // reading lines normally failed, try safe mode
          await import(_storageFs!.readSafeLines());
        }
        // if corrupted and not even meta
        // delete it
        if (corrupted && meta == null) {
          await _recreateStorageFs();
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
        var result = await _jdbFullMetaAndImport(options: openOptions);
        _meta = result.meta;
      }
      // Add all records to transaction record
      for (var store in _stores.values) {
        var txnRecords = store.txnRecords ??= <Object, TxnRecord>{};
        for (var entry in store.recordMapEntries) {
          txnRecords[entry.key] = TxnRecord(entry.value);
        }
      }
    });
  }

  /// Close and open
  Future<Database> reOpen([DatabaseOpenOptions? options]) async {
    /// Fix openMode
    if (options?.mode != null) {
      openHelper.openMode = options!.mode;
    }
    options ??= openOptions;
    await close();
    if (_storageJdb != null) {
      return openHelper.factory.openDatabase(
        path,
        version: options.version,
        onVersionChanged: options.onVersionChanged,
        codec: options.codec,
        mode: options.mode,
      );
    }
    // Reuse same open mode unless specified
    return open(options);
  }

  void _checkMainStore() {
    if (_mainStore == null) {
      _addStore(null);
    }
  }

  SembastStore _addStore(String? storeName) {
    if (storeName == null) {
      return _mainStore = _addStore(dbMainStore);
    } else {
      var store = SembastStore(this, storeName);
      _stores[storeName] = store;
      return store;
    }
  }

  ///
  /// find existing store
  ///
  SembastStore? findStore(String storeName) {
    SembastStore? store;
    store = _stores[storeName];

    return store;
  }

  /// Find a store in a transaction.
  SembastTransactionStore? txnFindStore(
    SembastTransaction txn,
    String storeName,
  ) {
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
  SembastStore getStore(String storeName) {
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
  SembastStore getSembastStore(StoreRef<Key?, Value?> ref) {
    _checkOpen();
    var store = findStore(ref.name);
    store ??= _addStore(ref.name);

    return store;
  }

  /// Get a store in a transaction.
  SembastTransactionStore? txnGetStore(
    SembastTransaction txn,
    String storeName,
  ) {
    var store = getSembastStore(SembastStoreRef<Key?, Value?>(storeName));
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
  Future<void> txnDeleteStore(SembastTransaction txn, String storeName) async {
    var store = await _txnClearStore(txn, storeName);
    if (store != null) {
      // do not delete main
      if (store.store != mainStore) {
        _txnDroppedStores.add(storeName);
      }
    }
  }

  /// Clear all records of a store in a transaction.
  Future<void> txnClearStore(SembastTransaction txn, String storeName) async {
    await _txnClearStore(txn, storeName);
  }

  /// Clear all records of a store in a transaction.
  Future<SembastTransactionStore?> _txnClearStore(
    SembastTransaction txn,
    String storeName,
  ) async {
    var store = txnFindStore(txn, storeName);
    if (store != null) {
      await store.store.txnClear(txn);
    }
    return store;
  }

  /// Undelete a store in a transaction
  void txnUndeleteStore(SembastTransaction txn, String storeName) {
    _txnDroppedStores.remove(storeName);
  }

  /// Flush changes.
  Future flush() async {
    // Wait for pending transaction
    await transactionLock.synchronized(() {});
    // Wait for pending writes
    await databaseOperation(null);
  }

  Future<_MetaAndImportResult> _fsFullMetaAndImport(
    Stream<String> lines, {
    bool? safeMode,
    required DatabaseOpenOptions options,
  }) async {
    // empty export stat
    _exportStat = DatabaseExportStat();

    var hasAsyncCodec = _contentCodec.isAsyncCodec;
    Meta? meta;
    var corrupted = false;
    var openMode = options.mode ?? DatabaseMode.defaultMode;
    var firstLineRead = false;

    await for (var line in lines) {
      _exportStat!.lineCount++;

      Map? map;

      // Until meta is read, we assume it is json
      if (!firstLineRead) {
        // Read the meta first
        // The first line is always json
        try {
          map = (json.decode(line) as Map?)?.cast<String, Object?>();
        } on Exception catch (_) {}
        if (Meta.isMapMeta(map)) {
          // meta?
          meta = Meta.fromMap(map!);

          // Check codec signature if any
          await checkCodecEncodedSignature(options.codec, meta.codecSignature);
          firstLineRead = true;
          continue;
        } else {
          // If a codec is used, we fail
          if (openMode == DatabaseMode.neverFails &&
              options.codec?.signature == null) {
            corrupted = true;
            break;
          } else {
            throw const FormatException('Invalid database format');
          }
        }
      }

      try {
        // decode record
        if (hasAsyncCodec) {
          map = await decodeRecordLineStringAsync(line);
        } else {
          map = decodeRecordLineStringSync(line);
        }
      } on Exception catch (_) {
        // We can have meta here
        try {
          map = (json.decode(line) as Map?);
        } on Exception catch (_) {
          if (openMode == DatabaseMode.neverFails) {
            corrupted = true;
            if (safeMode ?? false) {
              // safe mode ignore
              continue;
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      if (isMapRecord(map!)) {
        // record?
        ImmutableSembastRecord record;
        try {
          // Can crash for key without value
          record = ImmutableSembastRecord.fromDatabaseRowMap(map);
          if (_noTxnHasRecord(record)) {
            _exportStat!.obsoleteLineCount++;
          }
          loadRecord(record);
        } catch (_) {
          if (openMode == DatabaseMode.neverFails) {
            corrupted = true;
            if (safeMode ?? false) {
              // safe mode ignore
              continue;
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      } else if (Meta.isMapMeta(map)) {
        // meta?
        meta = Meta.fromMap(map);

        // Check codec signature if any
        await checkCodecEncodedSignature(options.codec, meta.codecSignature);
      } else {
        // If a codec is used, we fail
        if (openMode == DatabaseMode.neverFails && options.codec == null) {
          corrupted = true;
          break;
        } else {
          throw const FormatException('Invalid database format');
        }
      }
    }
    return _MetaAndImportResult(corrupted, meta);
  }

  Future<_MetaAndImportResult> _jdbFullMetaAndImport({
    required DatabaseOpenOptions options,
  }) async {
    // empty export stat
    _exportStat = DatabaseExportStat();
    var map = await _storageJdb!.readMeta();
    Meta? meta;
    if (Meta.isMapMeta(map)) {
      // meta?
      meta = Meta.fromMap(map!);

      // Check codec signature if any
      await checkCodecEncodedSignature(options.codec, meta.codecSignature);
    }

    await jdbFullImport();
    if (_jdbNeedCompact) {
      await txnCompact();
    }
    return _MetaAndImportResult(false, meta);
  }

  ///
  /// open a database
  ///
  Future<Database> open(DatabaseOpenOptions options) async {
    // Default mode
    // Open is overriden in openHelper
    var mode = openHelper.openMode;
    var version = options.version;

    if (_opened) {
      return this;
    }

    // Check codec
    if (options.codec != null) {
      if (options.codec!.signature == null) {
        if (options.codec!.codec != null) {
          throw DatabaseException.invalidCodec(
            'Codec signature cannot be null',
          );
        }
      } else {
        if (options.codec!.codec == null) {
          throw DatabaseException.invalidCodec(
            'Codec implementation cannot be null',
          );
        }
      }
    }

    await databaseLock.synchronized(() async {
      // needed for reOpen
      _closed = false;

      try {
        Meta? meta;

        Future handleVersionChanged(int? oldVersion, int? newVersion) async {
          _upgrading = true;
          try {
            await transaction((txn) async {
              Object? result;
              try {
                // create a transaction during open
                _openTransaction = txn;

                meta =
                    _upgradingMeta = Meta(
                      version: newVersion,
                      codecSignature: await getCodecEncodedSignatureOrNull(
                        options.codec,
                      ),
                    );

                // Eventually run onVersionChanged
                // Change will be committed when the transaction terminates
                if (options.onVersionChanged != null) {
                  result = await options.onVersionChanged!(
                    this,
                    oldVersion!,
                    newVersion!,
                  );
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

        Future openDone() async {
          // make sure mainStore is created
          _checkMainStore();

          // Set current meta
          // so that it is an old value during onVersionChanged
          meta ??= Meta(
            version: 0,
            codecSignature: await getCodecEncodedSignatureOrNull(options.codec),
          );

          _meta ??= meta;

          var needVersionChanged = false;

          final oldVersion = meta!.version;

          if (oldVersion == 0) {
            needVersionChanged = true;

            // Make version 1 by default
            version ??= 1;

            meta = Meta(
              version: version,
              codecSignature: await getCodecEncodedSignatureOrNull(
                options.codec,
              ),
            );
          } else {
            // no specific version requested or same
            if ((version != null) && (version != oldVersion)) {
              needVersionChanged = true;
            }
          }

          // mark it opened
          _opened = true;

          if (needVersionChanged) {
            await handleVersionChanged(oldVersion, version);
          }
          _meta = meta;
        }

        //_path = path;
        Future findOrCreate() async {
          if (mode == DatabaseMode.existing || mode == DatabaseMode.readOnly) {
            final found = await _storageBase!.find();
            if (!found) {
              throw DatabaseException.databaseNotFound(
                'Database (open existing or read-only) $path not found',
              );
            }

            /// Once used, change the mode to existing to handle any re-open
            openHelper.openMode = DatabaseMode.defaultMode;
          } else {
            if (mode == DatabaseMode.empty) {
              await _storageBase!.delete();

              /// Once used, change the mode to existing to handle any re-open
              openHelper.openMode = DatabaseMode.defaultMode;
            }
            await _storageBase!.findOrCreate();
          }
        }

        await findOrCreate();
        if (_storageBase!.supported) {
          void clearBeforeImport() {
            // empty stores and meta
            _exportStat = DatabaseExportStat();
            _meta = null;
            _mainStore = null;
            _stores.clear();
            _checkMainStore();
            listener.close();
            changesListener.close();
            _pendingListenerContent.clear();
          }

          if (_storageFs?.supported ?? false) {
            var corrupted = false;

            Future import(Stream<String> lines, {bool? safeMode}) async {
              clearBeforeImport();
              var result = await _fsFullMetaAndImport(
                lines,
                safeMode: safeMode,
                options: options,
              );
              corrupted = result.corrupted;
              meta = result.meta;
            }

            try {
              await import(_storageFs!.readLines(), safeMode: true);
            } catch (e) {
              corrupted = true;
              // reading lines normally failed, try safe mode
              await import(_storageFs!.readSafeLines());
            }
            // if corrupted and not even meta
            // delete it
            if (corrupted && meta == null) {
              if (mode != DatabaseMode.readOnly) {
                await _storageFs!.delete();
                await _storageFs!.findOrCreate();
              }
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
            clearBeforeImport();
            var result = await _jdbFullMetaAndImport(options: options);

            /// Revision update to force reading
            _storageJdbRevisionUpdateSubscription = _storageJdb!.revisionUpdate
                .listen((revision) {
                  jdbDeltaImport(revision);
                });
            _meta = meta = result.meta;
          }

          return await openDone();
        } else {
          // ensure main store exists
          // but do not erase previous data
          _checkMainStore();
          meta = _meta;
          return await openDone();
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
    _jdbRevision = await _storageJdb!.getRevision();
    await for (var entry in _storageJdb!.entries) {
      var record = ImmutableSembastRecordJdb(
        entry.record,
        entry.deleted ? null : entry.value,
        deleted: entry.deleted,
        revision: entry.id,
      );
      _exportStat!.lineCount++;
      // Make it fast
      if (entry.deleted) {
        _exportStat!.obsoleteLineCount++;
      }
      loadRecord(record);
    }
  }

  /// notify imported result
  void _notifyLazilyJdbImportResult(JdbImportResult result) {
    if (!result.delta) {
      _restartListeners();
    } else {
      _notifyListeners();
    }
  }

  /// Delta import. Must not be in a transaction
  Future jdbDeltaImport(int revision) async {
    var result = await transaction((txn) async {
      return await txnJdbDeltaImport(revision);
    });
    _notifyLazilyJdbImportResult(result);
  }

  void _addRecordToPendingListenerContent(ImmutableSembastRecord record) {
    // Add to listener if needed
    if (listener.recordHasAnyListener(record.ref)) {
      _pendingListenerContent.addRecord(record);
    }
  }

  /// Delta import. Must be in a transaction
  ///
  /// Also feed content listener
  Future<JdbImportResult> txnJdbDeltaImport(int? revision) async {
    bool delta;
    var minRevision = _jdbRevision ?? 0;
    var deltaMinRevision = await _storageJdb!.getDeltaMinRevision();

    if (minRevision >= deltaMinRevision) {
      delta = true;
      var entries = await _storageJdb!.getEntriesAfter(minRevision);
      // devPrint('delta import $entries $revision');
      if (!_closed) {
        for (var entry in entries) {
          // skip transaction empry record

          var record = ImmutableSembastRecordJdb(
            entry.record,
            entry.deleted ? null : entry.value,
            deleted: entry.deleted,
            revision: entry.id,
          );

          if (jdbDeltaLoadRecord(record)) {
            // Ignore already added/old record
            _addRecordToPendingListenerContent(record);
          }
        }
        _jdbRevision = revision;
      }
    } else {
      delta = false;
      _exportStat = DatabaseExportStat();
      var records = <ImmutableSembastRecordJdb>[];
      await for (var entry in _storageJdb!.entries) {
        var record = ImmutableSembastRecordJdb(
          entry.record,
          entry.deleted ? null : entry.value,
          deleted: entry.deleted,
          revision: entry.id,
        );
        _exportStat!.lineCount++;
        // Make it fast
        if (entry.deleted) {
          _exportStat!.obsoleteLineCount++;
        }
        records.add(record);
      }

      // Synchronous reload
      for (var store in stores) {
        store.clearRecordMap();
      }
      for (var record in records) {
        loadRecord(record);
      }
    }
    return JdbImportResult(delta: delta);
  }

  /// To call when in a databaseLock
  Future lockedClose() async {
    _opened = false;
    _closed = true;
    // Close the jdb database
    if (_storageJdb != null) {
      _storageJdb!.close();
    }
    await openHelper.lockedCloseDatabase();
  }

  @override
  Future close() async {
    if (debugPrintAbsoluteOpenedDatabasePath) {
      // ignore: avoid_print
      print('Closing ${normalize(absolute(path))}');
    }
    // jdb updates
    // ignore: unawaited_futures
    _storageJdbRevisionUpdateSubscription?.cancel();
    _storageJdbRevisionUpdateSubscription = null;

    return openHelper.lock.synchronized(() async {
      // Cancel listener
      listener.close();
      changesListener.close();
      // Make sure any pending changes are committed
      await flush();

      await lockedClose();
    });
  }

  /// info as json
  Map<String, Object?> toJson() {
    var map = <String, Object?>{};
    map['path'] = path;
    map['version'] = version;

    final stores = <Map<String, Object?>>[];
    for (var store in _stores.values) {
      stores.add(store.toJson());
    }
    map['stores'] = stores;

    if (_exportStat != null) {
      map['exportStat'] = _exportStat!.toJson();
    }
    return map;
  }

  /// Lazy store operations.
  final lazyStorageOperations = <Future<Object?> Function()>[];

  DatabaseExportStat? _exportStat;

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
    return (_storageFs != null) &&
        (_exportStat!.obsoleteLineCount > 5 &&
            (_exportStat!.obsoleteLineCount / _exportStat!.lineCount > 0.20));
  }

  /// For jdb, we compact has soon as we found an empty record
  bool get _jdbNeedCompact {
    return _exportStat!.obsoleteLineCount > 0;
  }

  @override
  String toString() {
    return toJson().toString();
  }

  /// Execute an exclusive operation on the database storage
  Future databaseOperation(Future Function()? action) async {
    // Don't lock if no pending operation, nor action
    if (lazyStorageOperations.isEmpty && action == null) {
      return;
    }
    await databaseLock.synchronized(() async {
      if (lazyStorageOperations.isNotEmpty) {
        var list = List<Future<Object?> Function()>.from(lazyStorageOperations);
        // devPrint('operation ${list.length}');
        for (var operation in list) {
          try {
            await operation();
          } catch (e) {
            if (_debugStorage) {
              // ignore: avoid_print
              print('lazy storage err $e');
            }
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
  Future<T> transaction<T>(SembastTransactionFunction<T> action) async {
    // during open?
    if (debugSembastWarnDatabaseCallInTransaction) {
      var futureValue = Future.value(_runTransaction(action));
      try {
        await futureValue.timeout(const Duration(seconds: 10));
      } on TimeoutException catch (_) {
        var txnInfo = Zone.current[this];
        if (txnInfo is DebugSembastTransactionZoneInfo) {
          // ignore: avoid_print
          print('# Currrent stack trace:');
          // ignore: avoid_print
          print(buildStackTrack());
          // ignore: avoid_print
          print(
            'Deadlock ? you likely called a database method in a '
            'transaction. Please use the transaction method to call '
            'database methods.',
          );
        }
      }
      return await futureValue;
    } else {
      return await _runTransaction(action);
    }
  }

  Future<T> _runTransaction<T>(SembastTransactionFunction<T> action) async {
    // during open?
    if (_openTransaction != null) {
      return await action(_openTransaction!);
    }

    CommitData? commitData;

    /// Can be true during open only when version changes.
    var upgrading = _upgrading;

    /// For jdb only
    var reloadData = false;
    late StorageJdbWriteResult jdbIncrementRevisionStatus;
    T result;
    do {
      if (reloadData) {
        await transactionLock.synchronized(() async {
          var result = await txnJdbDeltaImport(
            jdbIncrementRevisionStatus.revision,
          );

          // notify imported right away
          _notifyLazilyJdbImportResult(result);
        });
        reloadData = false;
      }
      result = await transactionLock
          .synchronized(() async {
            _transaction = SembastTransaction(this, ++_txnId);
            // To handle dropped stores

            void transactionCleanUp() {
              upgrading = false;

              _clearTxnData();
              // Mark transaction complete, ignore error
              _transaction?.completer.complete();

              // Compatibility remove transaction
              _transaction = null;
            }

            T actionResult;

            try {
              // devPrint('transaction ${jdbRevision}');
              actionResult = await Future<T>.sync(
                () =>
                    (debugSembastWarnDatabaseCallInTransaction)
                        ? runZoned(
                          () {
                            return action(_transaction!);
                          },
                          zoneValues: {this: DebugSembastTransactionZoneInfo()},
                        )
                        : action(_transaction!),
              );

              // Commit directly on jdb to handle transaction changes
              if (storageJdb != null) {
                var commitEntries = _txnBuildCommitEntries();

                /// Replay the transaction if something has changed
                if (commitEntries.hasWriteData || commitEntries.upgrading) {
                  // Build Entries
                  var entries = <JdbWriteEntry>[];
                  for (var record in commitEntries.txnRecords!) {
                    var entry = JdbWriteEntry(txnRecord: record);
                    entries.add(entry);
                  }
                  final infoEntries = <JdbInfoEntry>[
                    if (upgrading)
                      getMetaInfoEntry(commitEntries.upgradingMeta!),
                  ];
                  _txnStoreLastIntKeys.forEach((store, lastId) {
                    infoEntries.add(getStoreLastIntKeyInfoEntry(store, lastId));
                  });
                  var query = StorageJdbWriteQuery(
                    revision: commitEntries.revision,
                    entries: entries,
                    infoEntries: infoEntries,
                  );

                  // Commit to storage now
                  var status = await storageJdb!.writeIfRevision(query);
                  // devPrint(status);
                  if (!status.success!) {
                    reloadData = true;
                    jdbIncrementRevisionStatus = status;
                    transactionCleanUp();
                  } else {
                    _jdbRevision = status.revision;
                  }
                }
              }

              // if jdb failed, there will be no records
              commitData = commitInMemory();
            } catch (e) {
              transactionCleanUp();
              rethrow;
            } finally {
              // fs storage only
              if (_storageFs?.supported ?? false) {
                final hasRecords = commitData?.hasWriteData ?? false;

                if (hasRecords || upgrading) {
                  if (isReadOnly) {
                    // ignore: throw_in_finally
                    throw DatabaseException.badParam('Read-only database');
                  }
                  Future postTransaction() async {
                    // spawn commit if needed
                    // storagage commit and compacting is done lazily

                    //
                    // Write meta when upgrading, write before the records!
                    //
                    if (upgrading) {
                      await _storageFs!.appendLine(
                        json.encode(_upgradingMeta!.toMap()),
                      );
                      _exportStat!.lineCount++;
                    }
                    if (commitData?.txnRecords?.isNotEmpty == true) {
                      await storageCommitRecords(commitData!.txnRecords!);
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

            transactionCleanUp();

            return actionResult;
          })
          .whenComplete(() async {
            notifyListenersLazily();

            if (!upgrading) {
              // trigger lazy operation
              await databaseOperation(null);
            }
          });
    } while (reloadData);
    return result;
  }

  /// Sync way to know if post write is needed
  bool get txnPostWriteNeeded => changesListener.isNotEmpty;

  /// To call only when txnPostWriteNeeded is true
  Future<void> txnPostWrite(SembastTransaction txn) async {
    if (txnPostWriteNeeded) {
      await _txnHandleChanges(txn);
    }
  }

  /// To call after a write when cooperate is needed
  Future<void> txnPostWriteAndCooperate(SembastTransaction txn) async {
    if (txnPostWriteNeeded) {
      await txnPostWrite(txn);
    }
    await cooperate();
  }

  Future<void> _txnHandleChanges(SembastTransaction txn) async {
    while (changesListener.hasStoreChanges) {
      // Copy the list so that it never changes
      var storeChangesListeners = List<StoreChangesListeners>.from(
        changesListener.storeChangesListeners,
      );
      for (var storeChangesListener in storeChangesListeners) {
        if (storeChangesListener.hasChanges) {
          await storeChangesListener.handleChanges(txn);
        }
      }
    }
    while (changesListener.hasGlobalChanges) {
      await changesListener.handleGlobalChanges(txn);
    }
  }

  /// Lazily notify listeners
  void notifyListenersLazily() {
    _notifyListeners();
  }

  /// Our cooperator.
  var cooperator = cooperatorDisabled ? null : globalCooperator;

  /// True if activated.
  bool get cooperateOn => cooperator?.cooperateOn ?? false;

  /// True if cooperate needed.
  bool get needCooperate => cooperateNeeded(cooperator);

  /// Cooperate if needed.
  FutureOr cooperate() => cooperator?.cooperate();

  /// Ensure the transaction is still current
  void checkTransaction(SembastTransaction? transaction) {
    if (transaction != null && transaction != currentTransaction) {
      throw StateError(
        'The transaction is no longer active. Make sure you (a)wait all pending operations in your transaction block',
      );
    }
  }

  @override
  SembastDatabase get sembastDatabase => this;

  @override
  Future<T> inTransaction<T>(
    FutureOr<T> Function(SembastTransaction transaction) action,
  ) => transaction((txn) => action(txn as SembastTransaction));

  // Only set during open
  @override
  SembastTransaction? get sembastTransaction =>
      _openTransaction as SembastTransaction?;

  /// Needed after a full import
  void _restartListeners() {
    // A full import was done, re-run all queries
    for (var store in listener.stores) {
      var storeListener = listener.getStore(store)!;
      storeListener.restart();
    }
  }

  /// Notify listeners, if any of any pending changes
  Future<void> _notifyListeners() async {
    while (true) {
      var storeContent = _pendingListenerContent.getAndRemoveFirstStore();
      if (storeContent == null) {
        break;
      }
      // Since the content might change, we need to make a copy
      var records = List<ImmutableSembastRecord>.from(storeContent.records);
      var store = storeContent.store;
      var storeListener = listener.getStore(store);
      if (storeListener != null) {
        // Notify record listener in a global lock section
        await notificationLock.synchronized(() async {
          for (var record in records) {
            var ctlrs = storeListener.getRecordControllers(record.ref);
            if (ctlrs != null) {
              for (var ctlr in ctlrs) {
                ctlr.update(record);
              }
            }
          }

          var storeListenerControllers = List<StoreListenerController>.from(
            storeListener.getStoreListenerControllers<Key?, Value?>(),
          );
          // Fix existing queries
          for (var query in storeListenerControllers) {
            Future updateQuery() async {
              if (debugListener) {
                // ignore: avoid_print
                print('updating $query: with ${records.length} records ');
              }
              await query.update(records, cooperator);
              if (debugListener) {
                // ignore: avoid_print
                print('updated $query: with ${records.length} records ');
              }
            }

            if (query.hasInitialData) {
              await updateQuery();
            } else {
              // postpone after the current lock
              // ignore: unawaited_futures
              notificationLock.synchronized(() async {
                await updateQuery();
              });
            }
          }
        });
      }
    }
  }

  /// Sanitize a value.
  Value? sanitizeValue(Value? value) {
    if (value == null) {
      return null;
    } else if (value is num || value is String || value is bool) {
      return value;
    } else if (value is List) {
      return value;
    } else if (value is Map) {
      if (value is! Map<String, Object?>) {
        // We force the value map type for easy usage
        return value.cast<String, Object?>();
      }
      return value;
    }
    if (openOptions.codec!.jsonEncodableCodec.supportsType(value)) {
      return value;
    }
    throw ArgumentError.value(
      value,
      null,
      'type ${value.runtimeType} not supported',
    );
  }

  /// Use the one defined or the default one
  Codec<Object?, String> get _contentCodec =>
      sembastCodecContentCodec(openOptions.codec);

  /// Use the one defined or the default one
  JsonEncodableCodec get _jsonEncodableCodec =>
      openOptions.codec?.jsonEncodableCodec ?? sembastDefaultJsonEncodableCodec;

  /// Convert a value to a json encodable format
  Object toJsonEncodable(Object value) => _jsonEncodableCodec.encode(value);

  /// Convert a value from a json encodable format
  Object fromJsonEncodable(Object value) => _jsonEncodableCodec.decode(value);

  /// Sanitize a value.
  void _check(dynamic value, bool update) {
    if (update) {
      if (isBasicTypeFieldValueOrNull(value)) {
        return;
      }
    } else if (isBasicTypeOrNull(value)) {
      return;
    }

    if (value is List) {
      for (var item in value) {
        _check(item, update);
      }
      return;
    } else if (value is Map) {
      for (var item in value.values) {
        _check(item, update);
      }
      return;
    }
    if (_jsonEncodableCodec.supportsType(value)) {
      return;
    }

    throw ArgumentError.value(
      value,
      null,
      'type ${value.runtimeType} not supported',
    );
  }

  /// Sanitized an input value for the store
  V sanitizeInputValue<V>(Value value, {bool? update}) {
    update ??= false;
    if (update && (value is FieldValue)) {
      throw ArgumentError.value(value, '$value not supported at root');
    }
    _check(value, update);
    if (value is List) {
      try {
        return value.cast<Object?>() as V;
      } catch (e) {
        throw ArgumentError.value(
          value,
          'type $V not supported',
          'List must be of type List<Object?> for type ${value.runtimeType} value $value',
        );
      }
    } else if (value is Map) {
      try {
        // We force the value map type for easy usage
        return value.cast<String, Object?>() as V;
      } catch (e) {
        throw ArgumentError.value(
          value,
          'type $V not supported',
          'Map must be of type Map<String, Object?> for type ${value.runtimeType} value $value',
        );
      }
    }
    return value as V;
  }

  /// Listen for changes on a given store.
  void addOnChangesListener<K, V>(
    StoreRef<K, V> store,
    TransactionRecordChangeListener<K, V> onChanges,
  ) {
    changesListener.addStoreChangesListener<K, V>(store, onChanges);
  }

  /// Stop listening for changes.
  void removeOnChangesListener<K, V>(
    StoreRef<K, V> store,
    TransactionRecordChangeListener<K, V> onChanges,
  ) {
    changesListener.removeStoreChangesListener<K, V>(store, onChanges);
  }

  /// Listen for changes on all stores but.
  void addAllStoresOnChangesListener({
    required List<String>? excludedStoreNames,
    required TransactionRecordChangeListener onChanges,
  }) {
    changesListener.addGlobalChangesListener(
      onChanges,
      excludedStoreNames: excludedStoreNames,
    );
  }

  /// Listen for changes on all stores but.
  void removeAllStoresOnChangesListener(
    TransactionRecordChangeListener onChanges,
  ) {
    changesListener.removeGlobalChangesListener(onChanges);
  }
}

/// Build a stack trace
StackTrace buildStackTrack() {
  try {
    throw StateError('Stack trace');
  } catch (e, st) {
    return st;
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

  int _mapInt(Map map, String key) {
    var value = map[key];
    if (value is int) {
      return value;
    }
    return 0;
  }

  /// From a map.
  DatabaseExportStat.fromJson(Map map) {
    if (map['lineCount'] != null) {
      lineCount = _mapInt(map, 'lineCount');
    }
    if (map['compactCount'] != null) {
      compactCount = _mapInt(map, 'compactCount');
    }
    if (map['obsoleteLineCount'] != null) {
      obsoleteLineCount = _mapInt(map, 'obsoleteLineCount');
    }
  }

  /// To a map.
  Map<String, Object?> toJson() {
    var map = <String, Object?>{};

    map['lineCount'] = lineCount;
    map['obsoleteLineCount'] = obsoleteLineCount;
    map['compactCount'] = compactCount;
    return map;
  }

  @override
  String toString() => toJson().toString();
}

/// Import result.
class JdbImportResult {
  /// True if delta import.
  final bool delta;

  /// Import result.
  JdbImportResult({required this.delta});
}

/// Internal only
@protected
extension SembastDatabaseInternalExt on Database {
  SembastDatabase get _sembastDatabase => this as SembastDatabase;

  /// current sembast codec.
  SembastCodec? get sembastCodec => _sembastDatabase.openOptions.codec;

  /// Export/compact stat (debugging only)
  DatabaseExportStat? get exportStat => _sembastDatabase._exportStat;
}

class _MetaAndImportResult {
  final bool corrupted;
  final Meta? meta;

  _MetaAndImportResult(this.corrupted, this.meta);
}

/// All stores changes listener extension.
extension SembastDatabaseAllStoresChangesListenerExtension on Database {
  /// Listen for changes on all stores
  ///
  /// Note that the data is not type safe.
  ///
  /// To use with caution as it has a cost.
  ///
  /// Like transaction, it can run multiple times, so limit your changes to the
  /// database.
  void addAllStoresOnChangesListener(
    TransactionRecordChangeListener onChanges, {
    List<String>? excludedStoreNames,
  }) {
    (this as SembastDatabase).addAllStoresOnChangesListener(
      excludedStoreNames: excludedStoreNames,
      onChanges: onChanges,
    );
  }

  /// Remove a global change listener
  void removeAllStoresOnChangesListener(
    TransactionRecordChangeListener onChanges,
  ) {
    (this as SembastDatabase).removeAllStoresOnChangesListener(onChanges);
  }
}
