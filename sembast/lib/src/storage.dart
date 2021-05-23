import 'dart:async';

import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/meta.dart';

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
/// Storage io implementation
///
/// where the database is read/written to if needed
///
abstract class DatabaseStorage extends StorageBase {
  /// Tmp storage used.
  DatabaseStorage? get tmpStorage;

  /// Recover from a temp file.
  Future tmpRecover();

  /// Read all lines.
  Stream<String> readLines();

  /// Read safe lines, in case of corrupted data
  Stream<String> readSafeLines();

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

/// Increment revision operation
class StorageJdbIncrementRevisionStatus {
  /// The original known revision
  final int originalRevision;

  /// The revision read, +1 if matching the original revision.
  final int readRevision;

  /// Check if increment was a success. this means content has not changed.
  final bool success;

  /// Increment revision operation.
  StorageJdbIncrementRevisionStatus(
      this.originalRevision, this.readRevision, this.success);

  @override
  String toString() =>
      'original $originalRevision read $readRevision success $success';
}

/// Store last int key
String jdbStoreLastIdKey(String store) {
  return '${store}_store_last_id';
}

/// Create store last key info entry.
JdbInfoEntry getStoreLastIntKeyInfoEntry(String store, int? lastIntKey) =>
    JdbInfoEntry()
      ..id = jdbStoreLastIdKey(store)
      ..value = lastIntKey;

/// Create meta info entry.
JdbInfoEntry getMetaInfoEntry(Meta meta) => JdbInfoEntry()
  ..id = metaKey
  ..value = meta.toMap();

/// Jdb implementation
abstract class StorageJdb extends StorageBase {
  /// All entries.
  Stream<JdbEntry> get entries;

  /// Revision update to force reading
  Stream<StorageJdbStateUpdate>? get updates;

  /// Revision update to register on open (unregistre on close)
  Stream<int> get revisionUpdate;

  /// Get the entries after
  Future<List<JdbEntry>> getEntriesAfter(int revision);

  /// Read meta map
  Future<Map<String, Object?>?> readMeta();

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

  /// Increment the revision if not change
  Future<StorageJdbWriteResult> writeIfRevision(StorageJdbWriteQuery query);

  /// Test only.
  Map<String, Object?> toDebugMap();

  /// Compact the database removing obsolete records
  Future compact();

  /// Delta min revision.
  Future<int> getDeltaMinRevision();
}
