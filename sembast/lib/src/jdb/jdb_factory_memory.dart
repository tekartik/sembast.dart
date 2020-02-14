library sembast.jdb_factory_memory;

import 'dart:async';

import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/jdb.dart' as jdb;
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/record_impl.dart';

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
class JdbEntryMemory implements jdb.JdbReadEntry {
  @override
  int id;

  @override
  dynamic value;

  @override
  RecordRef record;

  @override
  bool deleted;

  /// Debug map.
  Map<String, dynamic> toDebugMap() {
    var map = <String, dynamic>{
      if (id != null) 'id': id,
      'store': record?.store?.name,
      'key': record?.key,
      'value': value,
      if (deleted ?? false) 'deleted': true
    };
    return map;
  }

  @override
  String toString() => toDebugMap().toString();
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
  final _revisionUpdatesCtrl = StreamController<int>.broadcast();

  /// Debug map.
  Map<String, dynamic> toDebugMap() {
    var map = <String, dynamic>{
      'entries':
          _entries.map((entry) => entry.toDebugMap()).toList(growable: false),
      'infos': _infoEntries.values
          .map((info) => info.toDebugMap())
          .toList(growable: false),
    };
    return map;
  }

  int _revision;
  @override
  Stream<jdb.JdbReadEntry> get entries async* {
    for (var entry in _entries) {
      _revision = entry.id;
      yield entry;
    }
  }

  /// New in memory database.
  JdbDatabaseMemory(this._factory, this._path);

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
  Future<int> addEntries(List<jdb.JdbWriteEntry> entries) async {
    // Should import?
    var revision = await getRevision() ?? 0;
    if ((_revision ?? 0) < revision) {
      _revisionUpdatesCtrl.add(revision);
    }
    for (var jdbWriteEntry in entries) {
      // remove existing
      var record = jdbWriteEntry.record;
      _entries.removeWhere((entry) => entry.record == record);
      var entry = JdbEntryMemory()
        ..record = record
        ..value = jdbWriteEntry.value
        ..id = _nextId
        ..deleted = jdbWriteEntry.deleted;
      _entries.add(entry);
      (jdbWriteEntry.txnRecord?.record as ImmutableSembastRecordJdb)?.revision =
          entry.id;
    }
    return null;
  }

  String _storeLastIdKey(String store) {
    return '${store}_store_last_id';
  }

  @override
  Future<List<int>> generateUniqueIntKeys(String store, int count) async {
    var keys = <int>[];
    var infoKey = _storeLastIdKey(store);
    var lastId = ((await getInfoEntry(infoKey))?.value as int) ?? 0;
    for (var i = 0; i < count; i++) {
      keys.add(++lastId);
    }
    await setInfoEntry(jdb.JdbInfoEntry()
      ..id = infoKey
      ..value = lastId);

    return keys;
  }

  @override
  Future<List<String>> generateUniqueStringKeys(
          String store, int count) async =>
      List.generate(count, (_) => generateStringKey());

  @override
  Stream<jdb.JdbEntry> entriesAfterRevision(int revision) async* {
    revision ??= 0;
    // Copy the list
    for (var entry in _entries.toList(growable: false)) {
      if ((entry.id ?? 0) > revision) {
        yield entry;
      }
    }
  }

  @override
  Future<int> getRevision() async {
    try {
      return _entries.last.id;
    } catch (e) {
      return null;
    }
  }

  @override
  Stream<int> get revisionUpdate => _revisionUpdatesCtrl.stream;
}

JdbFactoryMemory _jdbFactoryMemory = JdbFactoryMemory();

/// Jdb Factory in memory
JdbFactoryMemory get jdbFactoryMemory => _jdbFactoryMemory;
