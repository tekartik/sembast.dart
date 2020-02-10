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
  Map<String, dynamic> value;

  @override
  String toString() => '[$id] $value';
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

  Map<String, dynamic> _value;

  /// value.
  @override
  Map<String, dynamic> get value =>
      _value ??= txnRecord.record.toDatabaseRowMap();
  @override
  String toString() => '[$id] $record $value';

  @override
  bool get deleted => txnRecord.record.deleted;
}

/// Jdb.
abstract class JdbDatabase {
  /// Get info.
  Future<JdbInfoEntry> getInfoEntry(String id);

  /// Set info.
  Future setInfoEntry(JdbInfoEntry entry);

  /// Add en entry in the database.
  Future<int> addEntry(JdbEntry jdbEntry);

  /// Add entries in the database.
  Future addEntries(List<JdbWriteEntry> entries);

  /// Read all entries.
  Stream<JdbEntry> get entries;

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
