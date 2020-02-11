import 'dart:async';

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/constant_import.dart';
import 'package:sembast_web/src/jdb_import.dart' as jdb;
import 'package:sembast_web/src/sembast_import.dart';
import 'package:sembast_web/src/web_defs.dart';

var _debug = false; // devWarning(true); // false
const _infoStore = 'info';
const _entryStore = 'entry';
const _storePath = dbStoreNameKey;
const _keyPath = dbRecordKey;
const _recordIndex = 'record';
const _deletedIndex = 'deleted';
const _valuePath = dbRecordValueKey;
const _deletedPath = dbRecordDeletedKey;

/// last entry id inserted
const _revisionKey = 'revision';

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
  Future<jdb.JdbDatabase> open(String path) async {
    var id = ++_lastId;
    if (_debug) {
      print('[idb-$id] opening $path');
    }
    var iDb = await idbFactory.open(path, version: 2, onUpgradeNeeded: (event) {
      if (_debug) {
        print('[idb-$id] migrating ${event.oldVersion} -> ${event.newVersion}');
      }
      var db = event.database;
      db.createObjectStore(_infoStore);
      var entryStore = db.createObjectStore(_entryStore, autoIncrement: true);
      entryStore.createIndex(_recordIndex, [_storePath, _keyPath]);
      entryStore.createIndex(_deletedIndex, _deletedPath, multiEntry: true);
    });
    if (iDb != null) {
      var db = JdbDatabaseIdb(this, iDb, id, path);

      /// Add to our list
      if (path != null) {
        if (databases.isEmpty) {
          start();
        }
        var list = databases[path] ??= <JdbDatabaseIdb>[];
        list.add(db);
      }
      return db;
    }

    return null;
  }

  @override
  Future delete(String path) async {
    try {
      if (_debug) {
        print('[idb] deleting $path');
      }
      if (path != null) {
        databases.remove(path);
        checkAllClosed();
      }
      await idbFactory.deleteDatabase(path);
      if (_debug) {
        print('[idb] deleted $path');
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<bool> exists(String path) async {
    idb.Database db;
    try {
      db = await idbFactory.open(path);
      var meta = await db
          .transaction(_infoStore, idbModeReadOnly)
          .objectStore(_infoStore)
          .getObject(jdb.metaKey);
      if (meta is Map && meta['sembast'] is int) {
        return true;
      }
    } catch (_) {} finally {
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

  jdb.JdbReadEntry _entryFromCursor(CursorWithValue cwv) {
    var map = cwv.value as Map;
    var entry = jdb.JdbReadEntry()
      ..id = cwv.key as int
      ..record = StoreRef(map[_storePath] as String).record(map[_keyPath])
      ..value = map[_valuePath]
      ..deleted = map[_deletedPath] as bool;
    return entry;
  }

  final JdbFactoryIdb _factory;

  //final _entries = <JdbEntryIdb>[];
  String get _debugPrefix => '[idb-$_id]';

  @override
  Stream<jdb.JdbReadEntry> get entries {
    StreamController<jdb.JdbReadEntry> ctlr;
    ctlr = StreamController<jdb.JdbReadEntry>(onListen: () async {
      await _idbDatabase
          .transaction(_entryStore, idbModeReadOnly)
          .objectStore(_entryStore)
          .openCursor(autoAdvance: true)
          .listen((cwv) {
        var entry = _entryFromCursor(cwv);
        if (_debug) {
          print('$_debugPrefix reading entry $entry');
        }
        ctlr.add(entry);
      }).asFuture();

      await ctlr.close();
    });
    return ctlr.stream;
  }

  /// New in memory database.
  JdbDatabaseIdb(this._factory, this._idbDatabase, this._id, this._path);

  var _closed = false;

  @override
  void close() {
    if (!_closed) {
      // Clear from our list of open database
      if (_path != null) {
        var list = _factory.databases[_path];
        if (list != null) {
          list.remove(this);
          if (list.isEmpty) {
            _factory.databases.remove(_path);
          }
          _factory.checkAllClosed();
        }
      }
      if (_debug) {
        print('$_debugPrefix closing');
      }
      _closed = true;
      _idbDatabase?.close();
    }
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) async {
    var info = await _idbDatabase
        .transaction(_infoStore, idbModeReadOnly)
        .objectStore(_infoStore)
        .getObject(id);

    return jdb.JdbInfoEntry()
      ..id = id
      ..value = info;
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) async {
    var txn = _idbDatabase.transaction(_infoStore, idbModeReadWrite);
    await txn.objectStore(_infoStore).put(entry.value, entry.id);
    // await txn.completed;
  }

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) async {
    var txn =
        _idbDatabase.transaction([_entryStore, _infoStore], idbModeReadWrite);
    var objectStore = txn.objectStore(_entryStore);
    var infoStore = txn.objectStore(_infoStore);
    var index = objectStore.index(_recordIndex);
    int lastEntryId;
    for (var jdbWriteEntry in entries) {
      var store = jdbWriteEntry.record.store.name;
      var key = jdbWriteEntry.record.key;

      var idbKey = await index.getKey([store, key]);
      if (idbKey != null) {
        if (_debug) {
          print('$_debugPrefix deleting entry $idbKey');
        }
        await objectStore.delete(idbKey);
      }

      lastEntryId = (await objectStore.add(<String, dynamic>{
        _storePath: store,
        _keyPath: key,
        _valuePath: jdbWriteEntry.value,
        if (jdbWriteEntry.deleted ?? false) _deletedPath: true
      })) as int;
      // Save the revision in memory!
      jdbWriteEntry?.txnRecord?.record?.revision = lastEntryId;
      if (_debug) {
        print('$_debugPrefix added entry $lastEntryId $jdbWriteEntry');
      }
    }
    if (lastEntryId != null) {
      await infoStore.put(lastEntryId, _revisionKey);
    }
    await txn.completed;
    // notify through storage
    if (lastEntryId != null) {
      notifyRevision(lastEntryId);
    }
  }

  /// Notify other clients of the new revision
  void notifyRevision(int revision) {
    _factory.notifyRevision(StorageRevision(_path, revision));
  }

  @override
  String toString() => 'JdbDatabaseIdb($_id, $_path)';

  String _storeLastIdKey(String store) {
    return '${store}_store_last_id';
  }

  @override
  Future<List<int>> generateUniqueIntKeys(String store, int count) async {
    var keys = <int>[];
    var txn =
        _idbDatabase.transaction([_entryStore, _infoStore], idbModeReadWrite);
    var infoStore = txn.objectStore(_infoStore);
    var entryStore = txn.objectStore(_entryStore);
    var recordIndex = entryStore.index(_recordIndex);
    var infoKey = _storeLastIdKey(store);
    var lastId = (await infoStore.getObject(infoKey) as int) ?? 0;
    for (var i = 0; i < count; i++) {
      while (true) {
        lastId++;
        if (await recordIndex.getKey([store, lastId]) == null) {
          break;
        }
      }
      keys.add(lastId);
    }
    await infoStore.put(lastId, infoKey);
    return keys;
  }

  @override
  Future<List<String>> generateUniqueStringKeys(String store, int count) async {
    var keys = <String>[];
    var txn = _idbDatabase.transaction([_entryStore], idbModeReadWrite);
    var entryStore = txn.objectStore(_entryStore);
    var recordIndex = entryStore.index(_recordIndex);
    for (var i = 0; i < count; i++) {
      String key;
      while (true) {
        key = generateStringKey();
        if (await recordIndex.getKey([store, key]) == null) {
          break;
        }
      }
      keys.add(key);
    }
    return keys;
  }

  @override
  Stream<jdb.JdbEntry> entriesAfterRevision(int revision) {
    revision ??= 0;
    StreamController<jdb.JdbEntry> ctlr;
    ctlr = StreamController<jdb.JdbEntry>(onListen: () async {
      var keyRange = KeyRange.lowerBound(revision);
      await _idbDatabase
          .transaction(_entryStore, idbModeReadOnly)
          .objectStore(_entryStore)
          .openCursor(range: keyRange, autoAdvance: true)
          .listen((cwv) {
        var entry = _entryFromCursor(cwv);
        if (_debug) {
          print('$_debugPrefix reading entry after revision $entry');
        }
        ctlr.add(entry);
      }).asFuture();

      await ctlr.close();
    });
    return ctlr.stream;
  }

  @override
  Future<int> getRevision() async {
    return (await getInfoEntry(_revisionKey))?.value as int;
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdateController.stream;

  /// Will notify.
  void addRevision(int revision) {
    _revisionUpdateController.add(revision);
  }
}

JdbFactoryIdb _jdbFactoryIdbMemory = JdbFactoryIdb(idbFactoryMemory);

/// Jdb Factory in memory
JdbFactoryIdb get jdbFactoryIdbMemory => _jdbFactoryIdbMemory;
