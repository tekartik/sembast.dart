library sembast.sembast_jdb;

import 'dart:async';

import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/storage.dart';

/// meta info key
const String metaKey = 'meta';

/// Jdb Storage implementation.
class SembastStorageJdb extends StorageBase implements StorageJdb {
  /// The underlying jdb factory.
  final JdbFactory jdbFactory;

  /// The underlying jdb database.
  JdbDatabase? jdbDatabase;

  /// The open options, null for delete only.
  DatabaseOpenOptions? _optionsOrNull;

  /// Delete never call this.
  DatabaseOpenOptions get options => _optionsOrNull!;

  @override
  final String path;

  final bool _logV = databaseStorageLogLevel == SembastLogLevel.verbose;

  /// New storage instance. allow null options for delete only.
  SembastStorageJdb(this.jdbFactory, this.path,
      {DatabaseOpenOptions? options}) {
    _optionsOrNull = options;
  }

  @override
  bool get supported => true;

  @override
  Future<void> delete() async {
    try {
      // meta = null;
      await jdbFactory.delete(path);
    } catch (e) {
      if (_logV) {
        // ignore: avoid_print
        print('delete failed $path $e');
      }
    }
  }

  @override
  String toString() {
    final map = <String, Object?>{'path': path, 'jdb': jdbFactory.toString()};
    return map.toString();
  }

  @override
  Future<bool> find() async {
    try {
      if (jdbDatabase == null) {
        if (!await jdbFactory.exists(path)) {
          return false;
        }
        jdbDatabase = await jdbFactory.open(path, options);
      }
      return true;
    } catch (e) {
      if (_logV) {
        // ignore: avoid_print
        print('find failed $path $e');
      }
      return false;
    }
  }

  @override
  Future findOrCreate() async {
    jdbDatabase ??= await jdbFactory.open(path, options);
  }

  @override
  Future<Map<String, Object?>?> readMeta() async {
    var value = (await jdbDatabase!.getInfoEntry(metaKey))?.value;
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    return null;
  }

  @override
  void close() {
    try {
      jdbDatabase?.close();
    } catch (e) {
      if (_logV) {
        // ignore: avoid_print
        print('close failed $path $e');
      }
    }
  }

  @override
  Stream<JdbEntry> get entries => jdbDatabase!.entries;

  @override
  Future addEntries(List<JdbWriteEntry> entries) async {
    // devPrint(entries);
    await jdbDatabase!.addEntries(entries);
  }

  @override
  Future<int> generateUniqueIntKey(String store) async {
    return (await jdbDatabase!.generateUniqueIntKeys(store, 1)).first;
  }

  @override
  Future<String> generateUniqueStringKey(String store) async {
    return (await jdbDatabase!.generateUniqueStringKeys(store, 1)).first;
  }

  @override
  Future<List<JdbEntry>> getEntriesAfter(int revision) async {
    return await jdbDatabase!.entriesAfterRevision(revision).toList();
  }

  @override
  // TODO: implement updates
  Stream<StorageJdbStateUpdate>? get updates => null;

  @override
  Stream<int> get revisionUpdate => jdbDatabase!.revisionUpdate;

  @override
  Future<int> getRevision() => jdbDatabase!.getRevision();

  @override
  Future<StorageJdbWriteResult> writeIfRevision(StorageJdbWriteQuery query) =>
      jdbDatabase!.writeIfRevision(query);

  @override
  Map<String, Object?> toDebugMap() => {'path': path};

  @override
  Future compact() => jdbDatabase!.compact();

  @override
  Future<int> getDeltaMinRevision() => jdbDatabase!.getDeltaMinRevision();
}

/// Write query.
class StorageJdbWriteQuery {
  /// The info entries (meta)
  final List<JdbInfoEntry> infoEntries;

  /// The entries to write.
  final List<JdbWriteEntry> entries;

  /// The expected revision.
  final int? revision;

  /// Write query.
  StorageJdbWriteQuery(
      {required this.revision,
      required this.infoEntries,
      required this.entries});
}

/// Write result.
class StorageJdbWriteResult {
  /// The original query.
  final StorageJdbWriteQuery query;

  /// The read revision or the new one on success
  final int? revision;

  /// True on success, otherwise should reload data.
  final bool? success;

  /// Write result.
  StorageJdbWriteResult({required this.query, this.revision, this.success});

  @override
  String toString() =>
      'original ${query.revision} read $revision success $success';
}
