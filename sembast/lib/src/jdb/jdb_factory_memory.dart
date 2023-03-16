library sembast.jdb_factory_memory;

import 'dart:async';
import 'dart:math';

import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart' as jdb;
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/key_utils.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/storage.dart';

import '../api/store_ref.dart';

/// In memory jdb.
class JdbFactoryMemory implements jdb.JdbFactory {
  final _dbs = <String, JdbDatabaseMemory>{};

  @override
  Future<jdb.JdbDatabase> open(String path, DatabaseOpenOptions options) async {
    var db = _dbs[path];
    if (db == null) {
      db = JdbDatabaseMemory(this, path, options);
      db._closed = false;
      _dbs[path] = db;
    } else {
      // set the current open options
      db.openOptions = options;
    }
    return db;
  }

  @override
  Future<void> delete(String path) async {
    _dbs.remove(path);
  }

  @override
  Future<bool> exists(String path) async {
    return _dbs.containsKey(path);
  }

  @override
  String toString() => 'JdbFactoryMemory(${_dbs.length} dbs)';
}

bool _isMainStore(String? name) => name == null || name == dbMainStore;

/// In memory entry.
class JdbEntryMemory implements jdb.JdbReadEntryEncoded {
  @override
  final int id;

  @override
  final Object? valueEncoded;

  /// The record.
  final RecordRef<Key?, Value?> record;

  @override
  final bool deleted;

  /// In memory entry.
  JdbEntryMemory(
      {required this.id,
      required this.valueEncoded,
      required this.record,
      required this.deleted});

  /// Debug map.
  Map<String, Object?> exportToMap() {
    var map = <String, Object?>{
      'id': id,
      'value': <String, Object?>{
        if (!_isMainStore(record.store.name)) 'store': record.store.name,
        'key': record.key,
        if (!deleted) 'value': valueEncoded,
        if (deleted) 'deleted': true
      }
    };
    return map;
  }

  @override
  String toString() => exportToMap().toString();

  @override
  Object get recordKey => record.key!;

  @override
  String get storeName => store.name;

  /// Store.
  StoreRef<Key?, Value?> get store => record.store;
}

/// In memory database.
class JdbDatabaseMemory implements jdb.JdbDatabase {
  @override
  late DatabaseOpenOptions openOptions;
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

  /// New in memory database.
  JdbDatabaseMemory(this._factory, this._path, this.openOptions);

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

  JdbEntryMemory _writeEntryToMemory(jdb.JdbWriteEntryEncoded jdbWriteEntry) {
    var record = jdbWriteEntry.record;
    var deleted = jdbWriteEntry.deleted;
    var entry = JdbEntryMemory(
        record: record,
        id: _nextId,
        deleted: deleted,
        valueEncoded: jdbWriteEntry.valueEncoded);
    return entry;
  }

  @override
  Future<int> addEntries(List<jdb.JdbWriteEntry> entries) async {
    var entriesEncoded = await encodeEntries(entries);
    return _addEntries(entriesEncoded);
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

  int _addEntries(List<jdb.JdbWriteEntryEncoded> entries) {
    // devPrint('adding ${entries.length} uptodate $upToDate');
    for (var jdbWriteEntry in entries) {
      // remove existing
      _entries.removeWhere((entry) => entry.record == jdbWriteEntry.record);
      try {
        var entry = _writeEntryToMemory(jdbWriteEntry);
        _entries.add(entry);
        jdbWriteEntry.revision = entry.id;
      } catch (e) {
        print('Error importing $jdbWriteEntry: $e');
      }
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
  Stream<jdb.JdbEntry> get entries {
    return _getEntries();
  }

  @override
  Stream<jdb.JdbEntry> entriesAfterRevision(int revision) {
    return _getEntries(afterRevision: revision);
  }

  Stream<jdb.JdbEntry> _getEntries({int? afterRevision}) async* {
    for (var entry in _entries) {
      var revision = entry.id;
      // Update our incremental var
      _revision = max(_revision, revision);
      if (afterRevision != null) {
        if (revision <= afterRevision) {
          continue;
        }
      }
      var decoded = await decodeReadEntry(entry);
      yield decoded;
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
        _addEntries(await encodeEntries(query.entries));
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
