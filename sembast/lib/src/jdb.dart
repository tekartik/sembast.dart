library sembast.jdb;

import 'dart:async';

import 'package:sembast/src/record_impl.dart';

import 'api/v2/sembast.dart';

/// Jdb exception.
abstract class JdbException {
  /// Message describing the error.
  String get message;
}

/// Journal entry database.
class JdbInfoEntry {
  /// Jdb entry id.
  String id;

  /// Jdb value
  dynamic value;

  @override
  String toString() => '[$id] $value';

  /// Debug map.
  Map<String, dynamic> toDebugMap() {
    var map = <String, dynamic>{
      'id': id,
      'value': value,
    };
    return map;
  }
}

/// Journal entry database.
abstract class JdbEntry {
  /// Jdb entry id.
  int get id;

  /// Jdb record
  RecordRef get record;

  /// True if deleted
  bool get deleted;

  @override
  String toString() =>
      '[$id] $record $value${(deleted ?? false) ? ' (deleted)' : ''}';

  /// Jdb value
  dynamic get value;
}

/// Read entry
class JdbReadEntry extends JdbEntry {
  @override
  int id;

  @override
  RecordRef record;

  @override
  dynamic value;

  @override
  bool deleted;
}

/// Write entry.
class JdbWriteEntry extends JdbEntry {
  @override
  int id;

  /// Record
  TxnRecord txnRecord;

  // Ref.
  @override
  RecordRef get record => txnRecord.ref;

  dynamic _value;

  /// value.
  @override
  dynamic get value => _value ??= txnRecord.record.value;
  @override
  String toString() => '[$id] $record $value';

  @override
  bool get deleted => txnRecord.deleted;
}

/// Jdb.
abstract class JdbDatabase {
  /// Get revision update from the database
  Stream<int> get revisionUpdate;

  /// Get info.
  Future<JdbInfoEntry> getInfoEntry(String id);

  /// Set info.
  Future setInfoEntry(JdbInfoEntry entry);

  /// Add entries in the database.
  Future addEntries(List<JdbWriteEntry> entries);

  /// Read all entries.
  Stream<JdbEntry> get entries;

  /// Read delta entries since current revision
  Stream<JdbEntry> entriesAfterRevision(int revision);

  /// Read revision stored
  Future<int> getRevision();

  /// Generate unique int keys.
  Future<List<int>> generateUniqueIntKeys(String store, int count);

  /// Generate unique String keys.
  Future<List<String>> generateUniqueStringKeys(String store, int count);

  /// Close the database
  void close();
}

/// Jdb implementation.
abstract class JdbFactory {
  /// Open the database.
  Future<JdbDatabase> open(String path);

  /// Delete a database
  Future delete(String path);

  /// Check if a database exists
  Future<bool> exists(String path);
}
