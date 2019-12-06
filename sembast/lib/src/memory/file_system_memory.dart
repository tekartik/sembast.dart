library sembast.memory_file_system;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/src/file_system.dart' as fs;

import 'file_system_memory_impl.dart';

final FileSystemMemory _fs = FileSystemMemory();

/// In memory file system.
FileSystemMemory get memoryFileSystem => _fs;

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
