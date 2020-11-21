library sembast.jdb_factory_memory;

import 'dart:async';

import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/jdb.dart' as jdb;
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/storage.dart';

/// In memory jdb.
class JdbFactoryMemory implements jdb.JdbFactory {
  final _dbs = <String, JdbDatabaseMemory>{};

  @override
  Future<jdb.JdbDatabase> open(String path,
      {DatabaseOpenOptions? options}) async {
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

/// Simple transaction
class JdbTransactionEntryMemory extends JdbEntryMemory {
  /// Debug map.
  @override
  Map<String, Object?> exportToMap() {
    var map = <String, Object?>{'id': id, if (deleted) 'deleted': true};
    return map;
  }
}

bool _isMainStore(String? name) => name == null || name == dbMainStore;

/// In memory entry.
class JdbEntryMemory implements jdb.JdbReadEntry {
  @override
  late int id;

  @override
  Object? value;

  @override
  late RecordRef record;

  @override
  late bool deleted;

  /// Debug map.
  Map<String, Object?> exportToMap() {
    var map = <String, Object?>{
      'id': id,
      'value': <String, Object?>{
        if (!_isMainStore(record.store.name)) 'store': record.store.name,
        'key': record.key,
        'value': value,
        if (deleted) 'deleted': true
      }
    };
    return map;
  }

  @override
  String toString() => exportToMap().toString();
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
  final _infoEntries = <String?, jdb.JdbInfoEntry>{};
  final _revisionUpdatesCtrl = StreamController<int>.broadcast();

  /// Debug map.
  Map<String, Object?> toDebugMap() {
    var map = <String, Object?>{
      'entries':
          _entries.map((entry) => entry.exportToMap()).toList(growable: false),
      'infos': (List<jdb.JdbInfoEntry>.from(_infoEntries.values)
            ..sort((entry1, entry2) => entry1.id!.compareTo(entry2.id!)))
          .map((info) => info.exportToMap())
          .toList(growable: false),
    };
    return map;
  }

  int _revision = 0;

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
  Future<jdb.JdbInfoEntry?> getInfoEntry(String id) async {
    return _infoEntries[id];
  }

  jdb.JdbInfoEntry? _getInfoEntry(String id) {
    return _infoEntries[id];
  }

  @override
  Future setInfoEntry(jdb.JdbInfoEntry entry) async {
    _setInfoEntry(entry);
  }

  void _setInfoEntry(jdb.JdbInfoEntry entry) {
    _infoEntries[entry.id] = entry;
  }

  JdbEntryMemory _writeEntryToMemory(jdb.JdbWriteEntry jdbWriteEntry) {
    var record = jdbWriteEntry.record;
    var entry = JdbEntryMemory()
      ..record = record
      ..value = jdbWriteEntry.value
      ..id = _nextId
      ..deleted = jdbWriteEntry.deleted;
    return entry;
  }

  @override
  Future<int> addEntries(List<jdb.JdbWriteEntry> entries) async {
    return _addEntries(entries);
  }

  /// trigger a reload if needed, returns true if up to date
  bool _checkUpToDate() {
    var currentRevision = _getRevision();
    var upToDate = _revision == currentRevision;
    if (!upToDate) {
      _revisionUpdatesCtrl.add(currentRevision);
    }
    return upToDate;
  }

  int _addEntries(List<jdb.JdbWriteEntry> entries) {
    // devPrint('adding ${entries.length} uptodate $upToDate');
    for (var jdbWriteEntry in entries) {
      // remove existing
      var record = jdbWriteEntry.record;
      _entries.removeWhere((entry) => entry.record == record);
      var entry = _writeEntryToMemory(jdbWriteEntry);
      _entries.add(entry);
      (jdbWriteEntry.txnRecord?.record as ImmutableSembastRecordJdb?)
          ?.revision = entry.id;
    }
    return _lastEntryId;
  }

  String _storeLastIdKey(String store) => jdbStoreLastIdKey(store);

  @override
  Future<List<int>> generateUniqueIntKeys(String store, int count) async {
    var keys = <int>[];
    var infoKey = _storeLastIdKey(store);
    var lastId = ((await getInfoEntry(infoKey))?.value as int?) ?? 0;
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
    // Copy the list
    for (var entry in _entries.toList(growable: false)) {
      if ((entry.id) > revision) {
        yield entry;
      }
    }
  }

  @override
  Future<int> getRevision() async {
    return _getRevision();
  }

  int get _lastEntryId => _entries.isEmpty ? 0 : _entries.last.id;

  @override
  Stream<int> get revisionUpdate => _revisionUpdatesCtrl.stream;

  @override
  Future<StorageJdbWriteResult> writeIfRevision(
      StorageJdbWriteQuery query) async {
    var expectedRevision = query.revision ?? 0;
    var readRevision = _getRevision();
    var success = (expectedRevision == readRevision);

    if (success) {
      // _entries.add(JdbTransactionEntryMemory()..id = _nextId);
      if (query.entries.isNotEmpty) {
        _addEntries(query.entries);
      }
      readRevision = _revision = _lastEntryId;
      if (query.infoEntries.isNotEmpty) {
        for (var infoEntry in query.infoEntries) {
          _setInfoEntry(infoEntry);
        }
      }
    }
    // Also set the revision in the db but not in RAM
    if (_lastEntryId > 0) {
      _setRevision(_lastEntryId);
    }
    return StorageJdbWriteResult(
        revision: readRevision, query: query, success: success);
  }

  @override
  Future<Map<String, Object?>> exportToMap() async {
    return toDebugMap();
  }

  @override
  Future compact() async {
    var deltaMinRevision = _getDeltaMinRevision();
    var currentRevision = _getRevision();

    var newDeltaMinRevision = deltaMinRevision;
    var indecies = <int>[];
    for (var i = 0; i < _entries.length; i++) {
      var entry = _entries[i];
      var revision = entry.id;
      if (revision > newDeltaMinRevision && entry.deleted) {
        // Stop at current revision, we'll trigger a reload anyway
        if (revision > currentRevision) {
          break;
        }
        indecies.add(i);
        newDeltaMinRevision = revision;
      }
    }
    if (indecies.isNotEmpty) {
      for (var index in indecies.reversed) {
        _entries.removeAt(index);
      }
      _setDeltaMinRevision(newDeltaMinRevision);
    }
    // Trigger a reload
    _checkUpToDate();
  }

  int _getDeltaMinRevision() =>
      _getInfoEntry(deltaMinRevisionKey)?.value as int? ?? 0;

  int _getRevision() => _getInfoEntry(_revisionKey)?.value as int? ?? 0;

  void _setDeltaMinRevision(int revision) => _setInfoEntry(JdbInfoEntry()
    ..id = deltaMinRevisionKey
    ..value = revision);

  void _setRevision(int revision) => _setInfoEntry(JdbInfoEntry()
    ..id = _revisionKey
    ..value = revision);

  @override
  Future<int> getDeltaMinRevision() async => _getDeltaMinRevision();

  @override
  Future clearAll() async {
    _entries.clear();
    _infoEntries.clear();
  }
}

/// last entry id inserted
const _revisionKey = 'revision';

/// Delta import min revision
const deltaMinRevisionKey = 'deltaMinRevision';

JdbFactoryMemory _jdbFactoryMemory = JdbFactoryMemory();

/// Jdb Factory in memory
JdbFactoryMemory get jdbFactoryMemory => _jdbFactoryMemory;
