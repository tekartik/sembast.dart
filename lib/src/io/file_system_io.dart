library sembast.io_file_system;

import 'package:path/path.dart';

import '../file_system.dart' as fs;

import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';
import 'file_mode_io.dart';

///
/// the io file system global object
///
//final _IoFileSystem _fs = _IoFileSystem();
//_IoFileSystem get ioFileSystem => _fs;

// final FileSystemIo _defaultFileSystemIo = FileSystemIo();

io.FileMode _fileMode(fs.FileMode fsFileMode) {
  switch (fsFileMode) {
    case fs.FileMode.write:
      return fileModeWriteIo;
    case fs.FileMode.read:
      return fileModeReadIo;
    case fs.FileMode.append:
      return fileModeAppendIo;
    default:
      throw null;
  }
}

fs.FileSystemEntityType fsFileType(io.FileSystemEntityType type) {
  switch (type) {
    case fileSystemEntityTypeFileIo:
      return fs.FileSystemEntityType.file;
    case fileSystemEntityTypeDirectoryIo:
      return fs.FileSystemEntityType.directory;
    case fileSystemEntityTypeNotFoundIo:
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

class _IoOSError implements fs.OSError {
  io.OSError ioOSError;
  _IoOSError(this.ioOSError);

  @override
  int get errorCode => ioOSError.errorCode;

  @override
  String get message => ioOSError.message;

  @override
  String toString() => ioOSError.toString();
}

class _IoFileSystemException implements fs.FileSystemException {
  io.FileSystemException ioFse;
  _IoFileSystemException(this.ioFse) : osError = _IoOSError(ioFse.osError);

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

class FileSystemIo implements fs.FileSystem {
  final String rootPath;

  String normalizePath(String path) {
    if (rootPath != null) {
      return normalize(join(rootPath, path));
    } else {
      return normalize(path);
    }
  }

  FileSystemIo({this.rootPath});

  @override
  fs.File file(String path) {
    return FileIo(this, path);
  }

  @override
  fs.Directory directory(String path) {
    return DirectoryIo(this, path);
  }

  @override
  Future<bool> isFile(String path) =>
      io.FileSystemEntity.isFile(normalizePath(path));

  @override
  Future<bool> isDirectory(String path) =>
      io.FileSystemEntity.isDirectory(normalizePath(path));

  @override
  Future<fs.FileSystemEntityType> type(String path,
          {bool followLinks = true}) //
      =>
      _wrap(io.FileSystemEntity.type(normalizePath(path), followLinks: true))
          .then((io.FileSystemEntityType ioType) => fsFileType(ioType));

  @override
  DirectoryIo get currentDirectory => rootPath != null
      ? (directory('.') as DirectoryIo)
      : (io.Directory.current == null
          ? null
          : directory(io.Directory.current.path) as DirectoryIo);

  @override
  FileIo get scriptFile => io.Platform.script == null
      ? null
      : file(io.Platform.script.toFilePath()) as FileIo;

  @override
  String toString() => "io";
}

abstract class FileSystemEntityIo implements fs.FileSystemEntity {
  final FileSystemIo _fs;

  @override
  final String path;
  io.FileSystemEntity ioFileSystemEntity;

  FileSystemEntityIo(this._fs, this.path);

  @override
  Future<bool> exists() => _wrap(ioFileSystemEntity.exists());

  @override
  Future<fs.FileSystemEntity> delete({bool recursive = false}) //
      =>
      _wrap(ioFileSystemEntity.delete(recursive: recursive))
          .then((io.FileSystemEntity ioFileSystemEntity) => this);

  @override
  String toString() => ioFileSystemEntity.toString();

  @override
  fs.FileSystem get fileSystem => _fs;

  FileSystemIo get fileSystemIo => fileSystem as FileSystemIo;
}

class DirectoryIo extends FileSystemEntityIo implements fs.Directory {
  io.Directory get ioDir => ioFileSystemEntity as io.Directory;

  /// Creates a [DirectoryIo] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [DirectoryIo.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  DirectoryIo(FileSystemIo fs, String path) : super(fs, path) {
    ioFileSystemEntity = io.Directory(fileSystemIo.normalizePath(path));
  }

  @override
  Future<DirectoryIo> create({bool recursive = false}) //
      =>
      _wrap(ioDir.create(recursive: recursive))
          .then((io.Directory ioDir) => this);

  @override
  Future<fs.FileSystemEntity> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(fileSystemIo.normalizePath(path))).then(
          (io.FileSystemEntity ioFileSystemEntity) =>
              DirectoryIo(fileSystemIo, newPath));

  @override
  String toString() => "DirectoryIo: '$path'";
}

class FileIo extends FileSystemEntityIo implements fs.File {
  io.File get ioFile => ioFileSystemEntity as io.File;

  /// Creates a [FileIo] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [DirectoryIo.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  FileIo(FileSystemIo fs, String path) : super(fs, path) {
    ioFileSystemEntity = io.File(fileSystemIo.normalizePath(path));
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
  Future<FileIo> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(fileSystemIo.normalizePath(newPath)))
          .then((io.FileSystemEntity ioFileSystemEntity) =>
              FileIo(fileSystemIo, newPath));

  @override
  String toString() => "FileIo: '$path'";
}
