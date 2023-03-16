import 'dart:async';

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim/idb_shim.dart' as idb;
import 'package:sembast_web/src/jdb_import.dart' as jdb;
import 'package:sembast_web/src/jdb_import.dart';
import 'package:sembast_web/src/web_defs.dart';

import 'idb_constant.dart';
import 'jdb_database_idb.dart';

var _debug = false; // devWarning(true); // false

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
  Future<jdb.JdbDatabase> open(
      String path, DatabaseOpenOptions? options) async {
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
        db.createObjectStore(idbInfoStore);
        var entryStore =
            db.createObjectStore(idbEntryStore, autoIncrement: true);
        entryStore.createIndex(idbRecordIndex, [idbStoreKey, idbKeyKey]);
        entryStore.createIndex(idbDeletedIndex, idbDeletedKey,
            multiEntry: true);
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
          .transaction(idbInfoStore, idbModeReadOnly)
          .objectStore(idbInfoStore)
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

JdbFactoryIdb _jdbFactoryIdbMemory = JdbFactoryIdb(idbFactoryMemory);

/// Jdb Factory in memory
JdbFactoryIdb get jdbFactoryIdbMemory => _jdbFactoryIdbMemory;
