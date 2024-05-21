import 'dart:async';

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:idb_shim/utils/idb_import_export.dart' as import_export;
import 'package:sembast/src/storage.dart'; // ignore: implementation_imports
import 'package:sembast_web/src/constant_import.dart';
import 'package:sembast_web/src/jdb_import.dart' as jdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:sembast_web/src/sembast_import.dart';
import 'package:sembast_web/src/web_defs.dart';
import 'package:synchronized/synchronized.dart';

import 'idb_constant.dart';
import 'jdb_factory_idb.dart';

var _debug = false; // devWarning(true); // false

/// In memory database.
class JdbDatabaseIdb implements jdb.JdbDatabase {
  final idb.Database _idbDatabase;
  final int _id;
  final String _path;
  final _revisionUpdateController = StreamController<int>();
  final jdb.DatabaseOpenOptions? _options;

  @override
  jdb.DatabaseOpenOptions get openOptions => _options!;

  // It has to be a sync codec
  jdb.JdbReadEntry _entryFromCursorSync(CursorWithValue cwv) {
    var entryEncoded = _encodedEntryFromCursor(cwv);
    return decodeReadEntrySync(entryEncoded);
  }

  JdbReadEntryEncoded _encodedEntryFromCursor(CursorWithValue cwv) {
    var map = cwv.value as Map;

    // Deleted is an int in jdb
    var deleted = map[idbDeletedKey] == 1;

    var key = map[idbKeyKey] as Key;
    var storeName = map[idbStoreKey] as String;
    var id = cwv.key as int;

    Object? valueEncoded;
    if (!deleted) {
      valueEncoded = map[idbValueKey] as Object;
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
        // ignore: avoid_print
        print('$_debugPrefix closing');
      }
      _closed = true;
      _idbDatabase.close();
    }
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) async {
    var txn = _idbDatabase.transaction(idbInfoStore, idbModeReadOnly);
    return _txnGetInfoEntry(txn, id);
  }

  Future<jdb.JdbInfoEntry> _txnGetInfoEntry(
      idb.Transaction txn, String id) async {
    var info = await txn.objectStore(idbInfoStore).getObject(id);
    return jdb.JdbInfoEntry()
      ..id = id
      ..value = info;
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) async {
    var txn = _idbDatabase.transaction(idbInfoStore, idbModeReadWrite);
    await _txnSetInfoEntry(txn, entry);
    await txn.completed;
  }

  Future _txnSetInfoEntry(idb.Transaction txn, jdb.JdbInfoEntry entry) async {
    await txn.objectStore(idbInfoStore).put(entry.value as Object, entry.id);
  }

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) async {
    final entriesEncoded = await encodeEntries(entries);

    var txn = _idbDatabase
        .transaction([idbEntryStore, idbInfoStore], idbModeReadWrite);
    // var lastEntryId =
    await _txnAddEntries(txn, entriesEncoded);
    await txn.completed;

    /*
    don't notify - this is mainly for testing
     */
  }

  Future _txnPutRevision(idb.Transaction txn, int revision) async {
    var infoStore = txn.objectStore(idbInfoStore);
    await infoStore.put(revision, idbRevisionKey);
  }

  Future _txnPutDeltaMinRevision(idb.Transaction txn, int revision) async {
    var infoStore = txn.objectStore(idbInfoStore);
    await infoStore.put(revision, jdbDeltaMinRevisionKey);
  }

  Future<int?> _txnGetRevision(idb.Transaction txn) async {
    var infoStore = txn.objectStore(idbInfoStore);
    return (await infoStore.getObject(idbRevisionKey)) as int?;
  }

  // Return the last entryId
  Future<int?> _txnAddEntries(
      idb.Transaction txn, Iterable<JdbWriteEntryEncoded> entries) async {
    var objectStore = txn.objectStore(idbEntryStore);
    var index = objectStore.index(idbRecordIndex);
    int? lastEntryId;
    for (var jdbWriteEntry in entries) {
      var store = jdbWriteEntry.storeName;
      var key = jdbWriteEntry.recordKey;

      var idbKey = await index.getKey([store, key]);
      if (idbKey != null) {
        if (_debug) {
          // ignore: avoid_print
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
        idbStoreKey: store,
        idbKeyKey: key,
        if (value != null) idbValueKey: value,
        if (jdbWriteEntry.deleted) idbDeletedKey: 1
      })) as int;
      // Save the revision in memory!
      jdbWriteEntry.revision = lastEntryId;
      if (_debug) {
        // ignore: avoid_print
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
    var txn = _idbDatabase
        .transaction([idbEntryStore, idbInfoStore], idbModeReadOnly);
    var infoStore = txn.objectStore(idbInfoStore);
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

    var hasAsyncCodec = this.hasAsyncCodec;
    // Only for async codec
    var asyncCodecLock = Lock();
    ctlr = StreamController<jdb.JdbEntry>(onListen: () async {
      var keyRange = afterRevision == null
          ? null
          : KeyRange.lowerBound(afterRevision, true);
      var asyncCodecFutures = <Future>[];
      await _idbDatabase
          .transaction(idbEntryStore, idbModeReadOnly)
          .objectStore(idbEntryStore)
          .openCursor(range: keyRange, autoAdvance: true)
          .listen((cwv) {
        if (hasAsyncCodec) {
          var entry = _encodedEntryFromCursor(cwv);
          asyncCodecFutures.add(asyncCodecLock.synchronized(() async {
            var decoded = await decodeReadEntryAsync(entry);
            if (_debug) {
              // ignore: avoid_print
              print('$_debugPrefix reading async entry after revision $entry');
            }
            ctlr.add(decoded);
          }));
        } else {
          var entry = _entryFromCursorSync(cwv);
          if (_debug) {
            // ignore: avoid_print
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
    return (await getInfoEntry(idbRevisionKey)).value as int? ?? 0;
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdateController.stream;

  /// Will notify.
  void addRevision(int revision) {
    _revisionUpdateController.add(revision);
  }

  @override
  Future<StorageJdbWriteResult> writeIfRevision(
      StorageJdbWriteQuery query) async {
    // Encode before creating the transaction to handle async codec.
    var encodedList = await encodeEntries(query.entries);

    var expectedRevision = query.revision ?? 0;
    var txn = _idbDatabase
        .transaction([idbInfoStore, idbEntryStore], idbModeReadWrite);

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
    var txn = _idbDatabase
        .transaction([idbInfoStore, idbEntryStore], idbModeReadOnly);
    var map = <String, Object?>{};
    map['infos'] = await _txnStoreToDebugMap(txn, idbInfoStore);
    map['entries'] = await _txnStoreToDebugMap(txn, idbEntryStore);

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
        if (value[idbStoreKey] == debugSembastMainStoreName) {
          // Sembast main store TODO do not hardcode
          newMap ??= Map.from(value);
          newMap.remove(idbStoreKey);
        }
        // Hack to change deleted from 1 to true
        if (value[idbDeletedKey] == 1) {
          newMap ??= Map.from(value);
          newMap.remove(idbValueKey);
          newMap[idbDeletedKey] = true;
        }
        value = newMap ?? value;
      }
      list.add(<String, Object?>{'id': cwv.key, 'value': value});
    }).asFuture<void>();
    return list;
  }

  @override
  Future compact() async {
    var txn = _idbDatabase
        .transaction([idbInfoStore, idbEntryStore], idbModeReadWrite);
    var deltaMinRevision = await _txnGetDeltaMinRevision(txn);
    var currentRevision = await _txnGetRevision(txn) ?? 0;
    var newDeltaMinRevision = deltaMinRevision;
    var deleteIndex = txn.objectStore(idbEntryStore).index(idbDeletedIndex);
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
    return (await txn
            .objectStore(idbInfoStore)
            .getObject(jdbDeltaMinRevisionKey)) as int? ??
        0;
  }

  @override
  Future clearAll() async {
    var txn = _idbDatabase
        .transaction([idbInfoStore, idbEntryStore], idbModeReadWrite);
    await txn.objectStore(idbInfoStore).clear();
    await txn.objectStore(idbEntryStore).clear();
    await txn.completed;
  }

  /// Export the database using sdb format
  Future<Map> sdbExportDatabase() async =>
      import_export.sdbExportDatabase(_idbDatabase);
}
