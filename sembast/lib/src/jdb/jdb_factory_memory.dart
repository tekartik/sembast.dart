library sembast.jdb_factory_memory;

import 'dart:async';

import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/jdb.dart' as jdb;

/// In memory jdb.
class JdbFactoryMemory implements jdb.JdbFactory {
  final _dbs = <String, JdbDatabaseMemory>{};

  @override
  Future<jdb.JdbDatabase> open(String path) async {
    var db = _dbs[path];
    if (db == null) {
      db = JdbDatabaseMemory(this, path);
      db._closed = false;
      _dbs[path] = db;
    }
    return db;
  }

  @override
  Future delete(String path) async {
    _dbs.remove(path);
  }

  @override
  Future<bool> exists(String path) async {
    return _dbs.containsKey(path);
  }

  @override
  String toString() => 'JdbFactoryMemory(${_dbs.length} dbs)';
}

/// In memory entry.
class JdbEntryMemory implements jdb.JdbEntry {
  @override
  int id;

  @override
  Map<String, dynamic> value;

  @override
  RecordRef record;

  @override
  bool deleted;
}

/// In memory database.
class JdbDatabaseMemory implements jdb.JdbDatabase {
  int _lastId = 0;
  // ignore: unused_field
  bool _closed = false;

  int get _nextId => ++_lastId;
  // ignore: unused_field
  final JdbFactoryMemory _factory;
  // ignore: unused_field
  final String _path;
  final _entries = <JdbEntryMemory>[];
  final _infoEntries = <String, jdb.JdbInfoEntry>{};

  @override
  Stream<jdb.JdbEntry> get entries async* {
    for (var entry in _entries) {
      yield entry;
    }
  }

  /// New in memory database.
  JdbDatabaseMemory(this._factory, this._path);

  @override
  Future<int> addEntry(jdb.JdbEntry jdbEntry) async {
    var jdbEntryMemory = (jdbEntry as JdbEntryMemory);
    var id = _nextId;
    jdbEntryMemory.id = id;
    _entries.add(jdbEntryMemory);
    return id;
  }

  @override
  void close() {
    _closed = false;
  }

  @override
  Future<jdb.JdbInfoEntry> getInfoEntry(String id) async {
    return _infoEntries[id];
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) async {
    _infoEntries[entry.id] = entry;
  }

  @override
  Future addEntries(List<jdb.JdbWriteEntry> entries) {
    for (var jdbWriteEntry in entries) {
      // remove existing
      var record = jdbWriteEntry.record;
      _entries.removeWhere((entry) => entry.record == record);
      var entry = JdbEntryMemory()
        ..record = record
        ..value = jdbWriteEntry.value
        ..id = _nextId;
      _entries.add(entry);
    }
    return null;
  }
}

JdbFactoryMemory _jdbFactoryMemory = JdbFactoryMemory();

/// Jdb Factory in memory
JdbFactoryMemory get jdbFactoryMemory => _jdbFactoryMemory;
