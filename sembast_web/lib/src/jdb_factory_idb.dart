import 'dart:async';
import 'dart:convert';

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/utils/idb_import_export.dart' as import_export;
import 'package:sembast/src/storage.dart'; // ignore: implementation_imports
import 'package:sembast_web/src/constant_import.dart';
import 'package:sembast_web/src/jdb_entry_encoded.dart';
import 'package:sembast_web/src/jdb_import.dart' as jdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:sembast_web/src/sembast_import.dart';
import 'package:sembast_web/src/web_defs.dart';
import 'package:synchronized/synchronized.dart';

var _debug = false; // devWarning(true); // false
const _infoStore = 'info';
const _entryStore = 'entry';
const _storePath = dbStoreNameKey;
const _keyPath = dbRecordKey;
const _recordIndex = 'record';
const _deletedIndex = 'deleted';
const _valuePath = dbRecordValueKey;
const _deletedPath = dbRecordDeletedKey;

// TODO import from sembast
const _sembastMainStoreName = '_main';

/// last entry id inserted
const _revisionKey = jdbRevisionKey;

/// In memory jdb.
class JdbFactoryIdb implements jdb.JdbFactory {
  var _lastId = 0;

  /// The idb factory used
  final IdbFactory idbFactory;

  /// Idb factory
  JdbFactoryIdb(this.idbFactory);

  /// Keep track of open databases.
  final databases = <String, List<JdbDatabaseIdb>>{};

  @override
  Future<jdb.JdbDatabase> open(String path,
      {DatabaseOpenOptions? options}) async {
    var id = ++_lastId;
    if (_debug) {
      print('[idb-$id] opening $path');
    }
    var iDb = await idbFactory.open(path, version: 2, onUpgradeNeeded: (event) {
      if (_debug) {
        print('[idb-$id] migrating ${event.oldVersion} -> ${event.newVersion}');
      }
      var db = event.database;
      if (event.oldVersion < 2) {
        db.createObjectStore(_infoStore);
        var entryStore = db.createObjectStore(_entryStore, autoIncrement: true);
        entryStore.createIndex(_recordIndex, [_storePath, _keyPath]);
        entryStore.createIndex(_deletedIndex, _deletedPath, multiEntry: true);
      }
    });

    var db = JdbDatabaseIdb(this, iDb, id, path, options);

    /// Add to our list
    if (databases.isEmpty) {
      start();
    }
    var list = databases[path] ??= <JdbDatabaseIdb>[];
    list.add(db);

    return db;
  }

  @override
  Future<void> delete(String path) async {
    try {
      if (_debug) {
        print('[idb] deleting $path');
      }

      databases.remove(path);
      checkAllClosed();

      await idbFactory.deleteDatabase(path);
      notifyRevision(StorageRevision(path, 0));
      if (_debug) {
        print('[idb] deleted $path');
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<bool> exists(String path) async {
    late idb.Database db;
    try {
      db = await idbFactory.open(path);
      var meta = await db
          .transaction(_infoStore, idbModeReadOnly)
          .objectStore(_infoStore)
          .getObject(jdb.metaKey);
      if (meta is Map && meta['sembast'] is int) {
        return true;
      }
    } catch (_) {
    } finally {
      try {
        db.close();
      } catch (_) {}
    }
    return false;
  }

  @override
  String toString() => 'JdbFactoryIdb($idbFactory)';

  /// Stop if all databases are closed
  void checkAllClosed() {
    if (databases.isEmpty) {
      stop();
    }
  }

  /// Start (listeners), one db is opened.
  void start() {}

  /// Stop (listeners), alls dbs closed.
  void stop() {}

  /// Notify other app (web only))
  void notifyRevision(StorageRevision storageRevision) {
    if (debugStorageNotification) {
      print('notifyRevision $storageRevision: not supported');
    }
  }
}

/// In memory database.
class JdbDatabaseIdb implements jdb.JdbDatabase {
  final idb.Database _idbDatabase;
  final int _id;
  final String _path;
  final _revisionUpdateController = StreamController<int>();
  final jdb.DatabaseOpenOptions? _options;

  // It has to be a sync codec
  jdb.JdbReadEntry _entryFromCursor(CursorWithValue cwv) {
    var entryEncoded = _encodedEntryFromCursor(cwv);
    Object? value;
    if (!entryEncoded.deleted) {
      value = entryEncoded.valueEncoded;

      /// Optionally decode with content codec.
      if (_contentCodec != null && value is String) {
        value = _contentCodec!.decodeContentSync<Object>(value);
      }
      if (value != null) {
        /// Deserialize unsupported types (Blob, Timestamp)
        value = sembastCodecFromJsonEncodable(_sembastCodec, value);
      }
    }
    return _entryFromEncodedEntry(entryEncoded, value);
  }

  jdb.JdbReadEntry _entryFromEncodedEntry(
      JdbReadEntryEncoded encoded, Object? value) {
    var id = encoded.id;
    var store = StoreRef<Key?, Value?>(encoded.storeName);
    var record = store.record(encoded.recordKey);
    var deleted = encoded.deleted;
    var entry = jdb.JdbReadEntry()
      ..id = id
      ..record = record
      ..deleted = deleted;
    if (!deleted) {
      entry.value = value!;
    }
    return entry;
  }

  JdbReadEntryEncoded _encodedEntryFromCursor(CursorWithValue cwv) {
    var map = cwv.value as Map;

    // Deleted is an int in jdb
    var deleted = map[_deletedPath] == 1;

    var key = map[_keyPath] as Key;
    var storeName = map[_storePath] as String;
    var id = cwv.key as int;

    Object? valueEncoded;
    if (!deleted) {
      valueEncoded = map[_valuePath] as Object;
    }
    var entry = JdbReadEntryEncoded(id, storeName, key, deleted, valueEncoded);

    return entry;
  }

  final JdbFactoryIdb _factory;

  //final _entries = <JdbEntryIdb>[];
  String get _debugPrefix => '[idb-$_id]';

  @override
  Stream<jdb.JdbEntry> get entries => _entries();

  /// New in memory database.
  JdbDatabaseIdb(
      this._factory, this._idbDatabase, this._id, this._path, this._options);

  var _closed = false;

  @override
  void close() {
    if (!_closed) {
      // Clear from our list of open database

      var list = _factory.databases[_path];
      if (list != null) {
        list.remove(this);
        if (list.isEmpty) {
          _factory.databases.remove(_path);
        }
        _factory.checkAllClosed();
      }
      if (_debug) {
        print('$_debugPrefix closing');
      }
      _closed = true;
      _idbDatabase.close();
    }
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) async {
    var txn = _idbDatabase.transaction(_infoStore, idbModeReadOnly);
    return _txnGetInfoEntry(txn, id);
  }

  Future<jdb.JdbInfoEntry> _txnGetInfoEntry(
      idb.Transaction txn, String id) async {
    var info = await txn.objectStore(_infoStore).getObject(id);
    return jdb.JdbInfoEntry()
      ..id = id
      ..value = info;
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) async {
    var txn = _idbDatabase.transaction(_infoStore, idbModeReadWrite);
    await _txnSetInfoEntry(txn, entry);
    await txn.completed;
  }

  Future _txnSetInfoEntry(idb.Transaction txn, jdb.JdbInfoEntry entry) async {
    await txn.objectStore(_infoStore).put(entry.value as Object, entry.id);
  }

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) async {
    final entriesEncoded = await _encodeEntries(entries);

    var txn =
        _idbDatabase.transaction([_entryStore, _infoStore], idbModeReadWrite);
    // var lastEntryId =
    await _txnAddEntries(txn, entriesEncoded);
    await txn.completed;

    /*
    don't notify - this is mainly for testing
     */
  }

  Future _txnPutRevision(idb.Transaction txn, int revision) async {
    var infoStore = txn.objectStore(_infoStore);
    await infoStore.put(revision, _revisionKey);
  }

  Future _txnPutDeltaMinRevision(idb.Transaction txn, int revision) async {
    var infoStore = txn.objectStore(_infoStore);
    await infoStore.put(revision, jdbDeltaMinRevisionKey);
  }

  Future<int?> _txnGetRevision(idb.Transaction txn) async {
    var infoStore = txn.objectStore(_infoStore);
    return (await infoStore.getObject(_revisionKey)) as int?;
  }

  // Return the last entryId
  Future<int?> _txnAddEntries(
      idb.Transaction txn, Iterable<JdbWriteEntryEncoded> entries) async {
    var objectStore = txn.objectStore(_entryStore);
    var index = objectStore.index(_recordIndex);
    int? lastEntryId;
    for (var jdbWriteEntry in entries) {
      var store = jdbWriteEntry.storeName;
      var key = jdbWriteEntry.recordKey;

      var idbKey = await index.getKey([store, key]);
      if (idbKey != null) {
        if (_debug) {
          print('$_debugPrefix deleting entry $idbKey');
        }
        await objectStore.delete(idbKey);
      }

      /// Serialize value
      ///
      Object? value;
      if (!jdbWriteEntry.deleted) {
        value = jdbWriteEntry.valueEncoded;
      }
      //if
      lastEntryId = (await objectStore.add(<String, Object?>{
        _storePath: store,
        _keyPath: key,
        if (value != null) _valuePath: value,
        if (jdbWriteEntry.deleted) _deletedPath: 1
      })) as int;
      // Save the revision in memory!
      jdbWriteEntry.revision = lastEntryId;
      if (_debug) {
        print('$_debugPrefix added entry $lastEntryId $jdbWriteEntry');
      }
    }

    return lastEntryId;
  }

  /// Notify other clients of the new revision
  void notifyRevision(int revision) {
    _factory.notifyRevision(StorageRevision(_path, revision));
  }

  @override
  String toString() => 'JdbDatabaseIdb($_id, $_path)';

  String _storeLastIdKey(String store) => jdbStoreLastIdKey(store);

  @override
  Future<List<int>> generateUniqueIntKeys(String store, int count) async {
    var keys = <int>[];
    var txn =
        _idbDatabase.transaction([_entryStore, _infoStore], idbModeReadOnly);
    var infoStore = txn.objectStore(_infoStore);
    var infoKey = _storeLastIdKey(store);
    var lastId = (await infoStore.getObject(infoKey) as int?) ?? 0;

    for (var i = 0; i < count; i++) {
      lastId++;
      keys.add(lastId);
    }
    await txn.completed;
    return keys;
  }

  @override
  Future<List<String>> generateUniqueStringKeys(String store, int count) async {
    return List.generate(count, (index) => generateStringKey()).toList();
  }

  Stream<jdb.JdbEntry> _entries({int? afterRevision}) {
    late StreamController<jdb.JdbEntry> ctlr;

    var hasAsyncCodec = _hasAsyncCodec;
    var asyncCodecLock = hasAsyncCodec ? Lock() : null;
    ctlr = StreamController<jdb.JdbEntry>(onListen: () async {
      var keyRange = afterRevision == null
          ? null
          : KeyRange.lowerBound(afterRevision, true);
      var asyncCodecFutures = <Future>[];
      await _idbDatabase
          .transaction(_entryStore, idbModeReadOnly)
          .objectStore(_entryStore)
          .openCursor(range: keyRange, autoAdvance: true)
          .listen((cwv) {
        if (_hasAsyncCodec) {
          var entry = _encodedEntryFromCursor(cwv);
          var valueEncoded = entry.valueEncoded;
          // If there is a codec, it has to be a string, otherwise just
          // skip it.

          asyncCodecFutures.add(asyncCodecLock!.synchronized(() async {
            Object? value;
            if (!entry.deleted) {
              // The value for a codec is always a string.
              if (valueEncoded is String) {
                var encodable =
                    await _contentCodec!.decodeContentAsync(valueEncoded);
                value = sembastCodecFromJsonEncodable(_sembastCodec, encodable);
              } else {
                // cancel
                return;
              }
              // should not happen
              var decoded = _entryFromEncodedEntry(entry, value);
              ctlr.add(decoded);
            }
          }));
        } else {
          var entry = _entryFromCursor(cwv);
          if (_debug) {
            print('$_debugPrefix reading entry after revision $entry');
          }

          ctlr.add(entry);
        }
      }).asFuture<void>();
      if (hasAsyncCodec) {
        await Future.wait(asyncCodecFutures);
      }
      await ctlr.close();
    });
    return ctlr.stream;
  }

  @override
  Stream<jdb.JdbEntry> entriesAfterRevision(int revision) =>
      _entries(afterRevision: revision);

  @override
  Future<int> getRevision() async {
    return (await getInfoEntry(_revisionKey)).value as int? ?? 0;
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdateController.stream;

  /// Will notify.
  void addRevision(int revision) {
    _revisionUpdateController.add(revision);
  }

  /// True if it has async codec.
  bool get _hasAsyncCodec => _contentCodec?.isAsyncCodec ?? false;

  SembastCodec? get _sembastCodec => _options?.codec;

  /// Codec used
  Codec<Object?, String>? get _contentCodec =>
      sembastCodecContentCodecOrNull(_options?.codec);

  /// Encode entries, handling async codec if needed.
  Future<List<JdbWriteEntryEncoded>> _encodeEntries(
      Iterable<jdb.JdbWriteEntry> entries) async {
    var encodedList = <JdbWriteEntryEncoded>[];
    var jsonEncodableCodec = sembastCodecJsonEncodableCodec(_sembastCodec);
    final hasAsyncCodec = _hasAsyncCodec;
    var contentCodec = _contentCodec;
    for (var entry in entries) {
      Object? valueEncoded;
      if (!entry.deleted) {
        var value = entry.valueOrNull;
        if (value == null) {
          print('Invalid entry $entry');
          continue;
        }

        var encodableValue = jsonEncodableCodec.encode(value);

        /// If a codec is specified, write the value as a string instead.
        if (contentCodec != null) {
          if (hasAsyncCodec) {
            valueEncoded =
                await contentCodec.encodeContentAsync(encodableValue);
          } else {
            valueEncoded = contentCodec.encodeContentSync(encodableValue);
          }
        } else {
          valueEncoded = encodableValue;
        }
      }
      encodedList.add(JdbWriteEntryEncoded(entry, valueEncoded));
    }
    return encodedList;
  }

  @override
  Future<StorageJdbWriteResult> writeIfRevision(
      StorageJdbWriteQuery query) async {
    // Encode before creating the transaction to handle async codec.
    var encodedList = await _encodeEntries(query.entries);

    var expectedRevision = query.revision ?? 0;
    var txn =
        _idbDatabase.transaction([_infoStore, _entryStore], idbModeReadWrite);

    int? readRevision = (await _txnGetRevision(txn)) ?? 0;
    var success = (expectedRevision == readRevision);

    // Notify for the web
    int? shouldNotifyRevision;

    if (success) {
      if (query.entries.isNotEmpty) {
        readRevision = await _txnAddEntries(txn, encodedList);
        // Set revision info
        if (readRevision != null) {
          await _txnPutRevision(txn, readRevision);
          shouldNotifyRevision = readRevision;
        }
      }
      if (query.infoEntries.isNotEmpty) {
        for (var infoEntry in query.infoEntries) {
          await _txnSetInfoEntry(txn, infoEntry);
        }
      }
    }
    await txn.completed;
    if (shouldNotifyRevision != null) {
      notifyRevision(shouldNotifyRevision);
    }
    return StorageJdbWriteResult(
        revision: readRevision, query: query, success: success);
  }

  @override
  Future<Map<String, Object?>> exportToMap() async {
    var txn =
        _idbDatabase.transaction([_infoStore, _entryStore], idbModeReadOnly);
    var map = <String, Object?>{};
    map['infos'] = await _txnStoreToDebugMap(txn, _infoStore);
    map['entries'] = await _txnStoreToDebugMap(txn, _entryStore);

    return map;
  }

  Future<List<Map<String, Object?>>> _txnStoreToDebugMap(
      idb.Transaction txn, String name) async {
    var list = <Map<String, Object?>>[];
    var store = txn.objectStore(name);
    await store.openCursor(autoAdvance: true).listen((cwv) {
      dynamic value = cwv.value;

      if (value is Map) {
        Map? newMap;
        // hack to remove the store when testing
        if (value[_storePath] == _sembastMainStoreName) {
          // Sembast main store TODO do not har
          newMap ??= Map.from(value);
          newMap.remove(_storePath);
        }
        // Hack to change deleted from 1 to true
        if (value[_deletedPath] == 1) {
          newMap ??= Map.from(value);
          newMap.remove(_valuePath);
          newMap[_deletedPath] = true;
        }
        value = newMap ?? value;
      }
      list.add(<String, Object?>{'id': cwv.key, 'value': value});
    }).asFuture<void>();
    return list;
  }

  @override
  Future compact() async {
    var txn =
        _idbDatabase.transaction([_infoStore, _entryStore], idbModeReadWrite);
    var deltaMinRevision = await _txnGetDeltaMinRevision(txn);
    var currentRevision = await _txnGetRevision(txn) ?? 0;
    var newDeltaMinRevision = deltaMinRevision;
    var deleteIndex = txn.objectStore(_entryStore).index(_deletedIndex);
    await deleteIndex.openCursor(autoAdvance: true).listen((cwv) {
      assert(cwv.key is int);
      var revision = cwv.primaryKey as int;
      if (revision > newDeltaMinRevision && revision <= currentRevision) {
        newDeltaMinRevision = revision;
        cwv.delete();
      }
    }).asFuture<void>();
    // devPrint('compact $newDeltaMinRevision vs $deltaMinRevision, $currentRevision');
    if (newDeltaMinRevision > deltaMinRevision) {
      await _txnPutDeltaMinRevision(txn, newDeltaMinRevision);
    }
    await txn.completed;
  }

  @override
  Future<int> getDeltaMinRevision() async {
    return (await getInfoEntry(jdbDeltaMinRevisionKey)).value as int? ?? 0;
  }

  Future<int> _txnGetDeltaMinRevision(idb.Transaction txn) async {
    return (await txn.objectStore(_infoStore).getObject(jdbDeltaMinRevisionKey))
            as int? ??
        0;
  }

  @override
  Future clearAll() async {
    var txn =
        _idbDatabase.transaction([_infoStore, _entryStore], idbModeReadWrite);
    await txn.objectStore(_infoStore).clear();
    await txn.objectStore(_entryStore).clear();
    await txn.completed;
  }

  /// Export the database using sdb format
  Future<Map> sdbExportDatabase() async =>
      import_export.sdbExportDatabase(_idbDatabase);
}

JdbFactoryIdb _jdbFactoryIdbMemory = JdbFactoryIdb(idbFactoryMemory);

/// Jdb Factory in memory
JdbFactoryIdb get jdbFactoryIdbMemory => _jdbFactoryIdbMemory;
