library sembast.sembast_jdb;

import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/jdb.dart';
import 'package:sembast/src/storage.dart';

const String _metaKey = '_meta';

class _StorageJdb extends StorageBase implements StorageJdb {
  final JdbFactory jdbFactory;
  JdbDatabase jdbDatabase;

  // Map<String, dynamic> meta;
  @override
  final String path;

  bool isTmp;
  final bool logV = databaseStorageLogLevel == SembastLogLevel.verbose;

  _StorageJdb(this.jdbFactory, this.path);

  @override
  bool get supported => true;

  @override
  Future delete() async {
    try {
      // meta = null;
      await jdbFactory.delete(path);
    } catch (e) {
      if (logV) {
        print('delete failed $path $e');
      }
    }
  }

  @override
  String toString() {
    final map = <String, dynamic>{'path': path, 'jdb': jdbFactory.toString()};
    return map.toString();
  }

  @override
  Future<bool> find() async {
    try {
      if (jdbDatabase == null) {
        if (!await jdbFactory.exists(path)) {
          return false;
        }
        jdbDatabase = await jdbFactory.open(path);
      }
      return true;
    } catch (e) {
      if (logV) {
        print('find failed $path $e');
      }
      return false;
    }
  }

  @override
  Future findOrCreate() async {
    jdbDatabase ??= await jdbFactory.open(path);
  }

  @override
  Future<Map<String, dynamic>> readMeta() async {
    return (await jdbDatabase.getInfoEntry(_metaKey))?.value;
  }

  @override
  Future writeMeta(Map<String, dynamic> map) async {
    await jdbDatabase.setInfoEntry(JdbInfoEntry()
      ..id = _metaKey
      ..value = map);
  }

  void close() async {
    try {
      jdbDatabase?.close();
    } catch (e) {
      if (logV) {
        print('close failed $path $e');
      }
    }
  }

  @override
  Stream<JdbEntry> get entries => jdbDatabase.entries;

  @override
  Future addEntries(List<JdbWriteEntry> entries) async {
    // devPrint(entries);
    await jdbDatabase.addEntries(entries);
  }
}

/// Jdb implementation
class DatabaseFactoryJdb extends SembastDatabaseFactory
    with DatabaseFactoryMixin
    implements DatabaseFactory {
  /// File system used.
  final JdbFactory jdbFactory;

  /// Constructor.
  DatabaseFactoryJdb(this.jdbFactory);

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) =>
      SembastDatabase(openHelper, _StorageJdb(jdbFactory, openHelper.path));

  @override
  Future doDeleteDatabase(String path) async {
    return _StorageJdb(jdbFactory, path).delete();
  }

  @override
  bool get hasStorage => true;
}
