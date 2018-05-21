library sembast.memory_file_system;

import '../file_system.dart' as fs;
import 'memory_file_system_impl.dart';
import 'dart:async';
import 'dart:convert';

final _MemoryFileSystem _fs = new _MemoryFileSystem();
_MemoryFileSystem get memoryFileSystem => _fs;

class _MemoryFileSystem implements fs.FileSystem {
  MemoryFileSystemImpl _impl = new MemoryFileSystemImpl();

  _MemoryFileSystem();

  @override
  fs.File newFile(String path) {
    return new _MemoryFile(path);
  }

  @override
  fs.Directory newDirectory(String path) {
    return new _MemoryDirectory(path);
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
      {bool followLinks: true}) async {
    MemoryFileSystemEntityImpl entityImpl = _impl.getEntity(path);
    if (entityImpl != null) {
      return entityImpl.type;
    }
    return fs.FileSystemEntityType.notFound;
  }

  @override
  _MemoryDirectory get currentDirectory =>
      newDirectory(_impl.currentPath) as _MemoryDirectory;

  @override
  _MemoryFile get scriptFile => null;

  @override
  String toString() => "memory";
}

abstract class _MemoryFileSystemEntity implements fs.FileSystemEntity {
  @override
  final String path;

  _MemoryFileSystemEntity(this.path) {
    if (path == null) {
      throw new ArgumentError.notNull("path");
    }
  }

  @override
  Future<bool> exists() async => _fs._impl.exists(path);

  // don't care about recursive
  @override
  Future<fs.FileSystemEntity> delete({bool recursive: false}) async {
    _fs._impl.delete(path, recursive: recursive);
    return this;
  }

  @override
  String toString() => path;

  @override
  _MemoryFileSystem get fileSystem => _fs;
}

class _MemoryDirectory extends _MemoryFileSystemEntity implements fs.Directory {
  _MemoryDirectory(String path) : super(path);

  @override
  Future<_MemoryDirectory> create({bool recursive: false}) async {
    _fs._impl.createDirectory(path, recursive: recursive);
    return this;
  }

  @override
  Future<fs.FileSystemEntity> rename(String newPath) async {
    MemoryFileSystemEntityImpl renamed = _fs._impl.rename(path, newPath);
    return new _MemoryDirectory(renamed.path);
  }
}

class _MemoryFile extends _MemoryFileSystemEntity implements fs.File {
  //_MemoryFileImpl get fileImpl => impl;

  _MemoryFile(String path) : super(path);

  // don't care about recursive
  @override
  Future<fs.File> create({bool recursive: false}) async {
    _fs._impl.createFile(path, recursive: recursive);
    return this;
  }

  // don't care about start end
  @override
  Stream<List<int>> openRead([int start, int end]) => _fs._impl.openRead(path);

  // don't care about encoding - assume UTF8
  @override
  fs.IOSink openWrite(
          {fs.FileMode mode: fs.FileMode.write, Encoding encoding: utf8}) //
      =>
      _fs._impl.openWrite(path, mode: mode);

  @override
  Future<fs.File> rename(String newPath) async {
    MemoryFileSystemEntityImpl renamed = _fs._impl.rename(path, newPath);
    return new _MemoryFile(renamed.path);
  }
}
