library sembast.io_file_system;

import '../file_system.dart' as fs;

import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';
import 'io_file_mode.dart';

///
/// the io file system global object
///
final _IoFileSystem _fs = _IoFileSystem();
_IoFileSystem get ioFileSystem => _fs;

io.FileMode _fileMode(fs.FileMode fsFileMode) {
  switch (fsFileMode) {
    case fs.FileMode.write:
      return ioFileModeWrite;
    case fs.FileMode.read:
      return ioFileModeRead;
    case fs.FileMode.append:
      return ioFileModeAppend;
    default:
      throw null;
  }
}

fs.FileSystemEntityType fsFileType(io.FileSystemEntityType type) {
  switch (type) {
    case ioFileSystemEntityTypeFile:
      return fs.FileSystemEntityType.file;
    case ioFileSystemEntityTypeDirectory:
      return fs.FileSystemEntityType.directory;
    case ioFileSystemEntityTypeNotFound:
      return fs.FileSystemEntityType.notFound;
    default:
      throw type;
  }
}

class _IoIOSink implements fs.IOSink {
  final io.IOSink ioSink;
  _IoIOSink(this.ioSink);

  @override
  void writeln([Object obj = ""]) => ioSink.writeln(obj);

  @override
  Future close() => _wrap(ioSink.close());
}

abstract class FileSystemEntity implements fs.FileSystemEntity {
  io.FileSystemEntity ioFileSystemEntity;

  /// override
  /// Checks if type(path) returns FileSystemEntityType.FILE.
  static Future<bool> isFile(String path) => _fs.isFile(path);
  static Future<bool> isDirectory(String path) => _fs.isDirectory(path);

  @override
  Future<bool> exists() => _wrap(ioFileSystemEntity.exists());

  @override
  Future<fs.FileSystemEntity> delete({bool recursive = false}) //
      =>
      _wrap(ioFileSystemEntity.delete(recursive: recursive))
          .then((io.FileSystemEntity ioFileSystemEntity) => this);

  @override
  String get path => ioFileSystemEntity.path;

  @override
  String toString() => ioFileSystemEntity.toString();

  @override
  _IoFileSystem get fileSystem => _fs;
}

class _IoOSError implements fs.OSError {
  io.OSError ioOSError;
  _IoOSError(this.ioOSError);
  int get errorCode => ioOSError.errorCode;
  String get message => ioOSError.message;

  @override
  String toString() => ioOSError.toString();
}

class _IoFileSystemException implements fs.FileSystemException {
  io.FileSystemException ioFse;
  _IoFileSystemException(io.FileSystemException ioFse)
      : ioFse = ioFse,
        osError = _IoOSError(ioFse.osError);

  @override
  final _IoOSError osError;

  @override
  String get message => ioFse.message;

  @override
  String get path => ioFse.path;

  @override
  String toString() => ioFse.toString();
}

Future<T> _wrap<T>(Future<T> future) {
  return future.catchError((e) {
    if (e is io.FileSystemException) {
      throw _IoFileSystemException(e);
    }
    throw e;
  });
}

class _IoFileSystem implements fs.FileSystem {
  @override
  fs.File newFile(String path) {
    return File(path);
  }

  @override
  fs.Directory newDirectory(String path) {
    return Directory(path);
  }

  @override
  Future<bool> isFile(String path) => io.FileSystemEntity.isFile(path);

  @override
  Future<bool> isDirectory(String path) =>
      io.FileSystemEntity.isDirectory(path);

  @override
  Future<fs.FileSystemEntityType> type(String path,
          {bool followLinks = true}) //
      =>
      _wrap(io.FileSystemEntity.type(path, followLinks: true))
          .then((io.FileSystemEntityType ioType) => fsFileType(ioType));

  @override
  Directory get currentDirectory => io.Directory.current == null
      ? null
      : newDirectory(io.Directory.current.path) as Directory;

  @override
  File get scriptFile => io.Platform.script == null
      ? null
      : newFile(io.Platform.script.toFilePath()) as File;

  @override
  String toString() => "io";
}

class Directory extends FileSystemEntity implements fs.Directory {
  io.Directory get ioDir => ioFileSystemEntity as io.Directory;

  /// Creates a [Directory] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [Directory.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  Directory(String path) {
    ioFileSystemEntity = io.Directory(path);
  }

  @override
  Future<Directory> create({bool recursive = false}) //
      =>
      _wrap(ioDir.create(recursive: recursive))
          .then((io.Directory ioDir) => this);

  @override
  Future<FileSystemEntity> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(newPath)).then(
          (io.FileSystemEntity ioFileSystemEntity) =>
              Directory(ioFileSystemEntity.path));
}

class File extends FileSystemEntity implements fs.File {
  io.File get ioFile => ioFileSystemEntity as io.File;

  /// Creates a [File] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [Directory.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  File(String path) {
    ioFileSystemEntity = io.File(path);
  }

  @override
  Future<fs.File> create({bool recursive = false}) //
      =>
      _wrap(ioFile.create(recursive: recursive)).then((io.File ioFile) => this);

  @override
  Stream<List<int>> openRead([int start, int end]) //
      =>
      ioFile.openRead(start, end);

  @override
  fs.IOSink openWrite(
          {fs.FileMode mode = fs.FileMode.write, Encoding encoding = utf8}) //
      =>
      _IoIOSink(ioFile.openWrite(mode: _fileMode(mode), encoding: encoding));

  @override
  Future<File> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(newPath)).then(
          (io.FileSystemEntity ioFileSystemEntity) =>
              File(ioFileSystemEntity.path));
}
