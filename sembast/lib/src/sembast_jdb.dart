library sembast.sembast_jdb;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/jdb.dart';
import 'package:sembast/src/storage.dart';

/// meta info key
const String metaKey = 'meta';

/// Jdb Storage implementation.
class SembastStorageJdb extends StorageBase implements StorageJdb {
  /// The underlying jdb factory.
  final JdbFactory jdbFactory;

  /// The underlying jdb database.
  JdbDatabase jdbDatabase;

  @override
  final String path;

  final bool _logV = databaseStorageLogLevel == SembastLogLevel.verbose;

  /// New storage instance.
  SembastStorageJdb(this.jdbFactory, this.path);

  @override
  bool get supported => true;

  @override
  Future delete() async {
    try {
      // meta = null;
      await jdbFactory.delete(path);
    } catch (e) {
      if (_logV) {
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
      if (_logV) {
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
    var value = (await jdbDatabase.getInfoEntry(metaKey))?.value;
    if (value is Map) {
      return value?.cast<String, dynamic>();
    }
    return null;
  }

  @override
  void close() {
    try {
      jdbDatabase?.close();
    } catch (e) {
      if (_logV) {
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

  @override
  Future<int> generateUniqueIntKey(String store) async {
    return (await jdbDatabase.generateUniqueIntKeys(store, 1)).first;
  }

  @override
  Future<String> generateUniqueStringKey(String store) async {
    return (await jdbDatabase.generateUniqueStringKeys(store, 1)).first;
  }

  @override
  Future<List<JdbEntry>> getEntriesAfter(int revision) async {
    return await jdbDatabase.entriesAfterRevision(revision).toList();
  }

  @override
  // TODO: implement updates
  Stream<StorageJdbStateUpdate> get updates => null;

  @override
  Stream<int> get revisionUpdate => jdbDatabase.revisionUpdate;

  @override
  Future<int> getRevision() => jdbDatabase.getRevision();

  @override
  Future<StorageJdbWriteResult> writeIfRevision(StorageJdbWriteQuery query) =>
      jdbDatabase.writeIfRevision(query);

  @override
  Future<Map<String, dynamic>> toDebugMap() {
    // TODO: implement toDebugMap
    return null;
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
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) => SembastDatabase(
      openHelper, SembastStorageJdb(jdbFactory, openHelper.path));

  @override
  Future doDeleteDatabase(String path) async {
    return SembastStorageJdb(jdbFactory, path).delete();
  }

  @override
  bool get hasStorage => true;
}

/// Write query.
class StorageJdbWriteQuery {
  /// The info entries (meta)
  final List<JdbInfoEntry> infoEntries;

  /// The entries to write.
  final List<JdbWriteEntry> entries;

  /// The expected revision.
  final int revision;

  /// Write query.
  StorageJdbWriteQuery(
      {@required this.revision,
      @required this.infoEntries,
      @required this.entries});
}

/// Write result.
class StorageJdbWriteResult {
  /// The original query.
  final StorageJdbWriteQuery query;

  /// The read revision or the new one on success
  final int revision;

  /// True on success, otherwise should reload data.
  final bool success;

  /// Write result.
  StorageJdbWriteResult({@required this.query, this.revision, this.success});

  @override
  String toString() =>
      'original ${query.revision} read $revision success $success';
}
