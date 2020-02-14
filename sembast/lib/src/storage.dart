import 'dart:async';

import 'package:sembast/src/jdb.dart';

/// Base storage
abstract class StorageBase {
  /// the storage path.
  String get path;

  /// true if supported.
  bool get supported;

  /// Delete the storage.
  Future delete();

  /// returns true if the storage exists.
  Future<bool> find();

  /// Create the storage if needed
  Future findOrCreate();
}

///
/// Storage implementation
///
/// where the database is read/written to if needed
///
abstract class DatabaseStorage extends StorageBase {
  /// Tmp storage used.
  DatabaseStorage get tmpStorage;

  /// Recover from a temp file.
  Future tmpRecover();

  /// Read all lines.
  Stream<String> readLines();

  /// Append multiple lines.
  Future appendLines(List<String> lines);

  /// Append one line
  Future appendLine(String line) => appendLines([line]);
}

/// State update
class StorageJdbStateUpdate {
  /// Current revision
  final int revision;

  /// Minimum version for delta import
  final int minDeltaImportRevision;

  /// State update
  StorageJdbStateUpdate(this.revision, this.minDeltaImportRevision);
}

/// Jdb implementation
abstract class StorageJdb extends StorageBase {
  /// All entries.
  Stream<JdbEntry> get entries;

  /// Revision update to force reading
  Stream<StorageJdbStateUpdate> get updates;

  /// Revision update to register on open (unregistre on close)
  Stream<int> get revisionUpdate;

  /// Get the entries after
  Future<List<JdbEntry>> getEntriesAfter(int revision);

  /// Read meta map
  Future<Map<String, dynamic>> readMeta();

  /// Write meta map
  Future writeMeta(Map<String, dynamic> map);

  /// Add multiple entries
  Future addEntries(List<JdbWriteEntry> entries);

  /// Close the db
  void close();

  /// Generate a unique int key
  Future<int> generateUniqueIntKey(String store);

  /// Generate a unique String key
  Future<String> generateUniqueStringKey(String store);

  /// Read the revision
  Future<int> getRevision();
}
