library sembast.jdb_factory_memory;

import 'dart:async';

import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/jdb.dart' as jdb;

/*
final FileSystemMemory _fs = FileSystemMemory();

/// In memory file system.
FileSystemMemory get memoryFileSystem => _fs;
*/

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

/*
/// In memory file system.
class FileSystemMemory implements fs.FileSystem {
  final _impl = FileSystemMemoryImpl();

  /// In memory file system.
  FileSystemMemory();

  @override
  fs.File file(String path) {
    return FileMemory(path);
  }

  @override
  fs.Directory directory(String path) {
    return DirectoryMemory(path);
  }

  @override
  Future<bool> isFile(String path) {
    return type(path, followLinks: true).then(
        (fs.FileSystemEntityType type) => type == fs.FileSystemEntityType.file);
  }

  @override
  Future<bool> isDirectory(String path) {
    return type(path, followLinks: true).then((fs.FileSystemEntityType type) =>
        type == fs.FileSystemEntityType.directory);
  }

  @override
  Future<fs.FileSystemEntityType> type(String path,
      {bool followLinks = true}) async {
    final entityImpl = _impl.getEntity(path);
    if (entityImpl != null) {
      return entityImpl.type;
    }
    return fs.FileSystemEntityType.notFound;
  }

  @override
  DirectoryMemory get currentDirectory =>
      directory(_impl.currentPath) as DirectoryMemory;

  @override
  FileMemory get scriptFile => null;

  @override
  String toString() => 'memory';
}

/// In memory file entity.
abstract class FileSystemEntityMemory implements fs.FileSystemEntity {
  @override
  final String path;

  /// In memory file entity.
  FileSystemEntityMemory(this.path) {
    if (path == null) {
      throw ArgumentError.notNull('path');
    }
  }

  @override
  Future<bool> exists() async => _fs._impl.exists(path);

  // don't care about recursive
  @override
  Future<fs.FileSystemEntity> delete({bool recursive = false}) async {
    _fs._impl.delete(path, recursive: recursive);
    return this;
  }

  @override
  String toString() => path;

  @override
  FileSystemMemory get fileSystem => _fs;
}

/// In memory directory entity.
class DirectoryMemory extends FileSystemEntityMemory implements fs.Directory {
  /// In memory directory entity.
  DirectoryMemory(String path) : super(path);

  @override
  Future<DirectoryMemory> create({bool recursive = false}) async {
    _fs._impl.createDirectory(path, recursive: recursive);
    return this;
  }

  @override
  Future<fs.FileSystemEntity> rename(String newPath) async {
    final renamed = _fs._impl.rename(path, newPath);
    return DirectoryMemory(renamed.path);
  }
}

/// In memory file entity.
class FileMemory extends FileSystemEntityMemory implements fs.File {
  //_MemoryFileImpl get fileImpl => impl;
  /// In memory file entity.
  FileMemory(String path) : super(path);

  // don't care about recursive
  @override
  Future<fs.File> create({bool recursive = false}) async {
    _fs._impl.createFile(path, recursive: recursive);
    return this;
  }

  // don't care about start end
  @override
  Stream<Uint8List> openRead([int start, int end]) => _fs._impl.openRead(path);

  // don't care about encoding - assume UTF8
  @override
  fs.IOSink openWrite(
          {fs.FileMode mode = fs.FileMode.write, Encoding encoding = utf8}) //
      =>
      _fs._impl.openWrite(path, mode: mode);

  @override
  Future<fs.File> rename(String newPath) async {
    final renamed = _fs._impl.rename(path, newPath);
    return FileMemory(renamed.path);
  }
}
*/
