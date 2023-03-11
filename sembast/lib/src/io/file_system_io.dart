library sembast.io_file_system;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/src/file_system.dart' as fs;
import 'package:sembast/src/utils.dart';

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
      throw fsFileMode;
  }
}

/// io to fs type.
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
  void writeln([Object obj = '']) => ioSink.writeln(obj);

  @override
  Future close() async {
    try {
      await ioSink.flush();
    } catch (_) {}
    return _wrap(ioSink.close());
  }
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

  _IoFileSystemException(this.ioFse) : osError = _IoOSError(ioFse.osError!);

  @override
  final _IoOSError osError;

  @override
  String get message => ioFse.message;

  @override
  String? get path => ioFse.path;

  @override
  String toString() => ioFse.toString();
}

class _FileSystemExceptionIoDefault implements fs.FileSystemException {
  _FileSystemExceptionIoDefault(this.message);

  @override
  _IoOSError? get osError => null;

  @override
  final String message;

  @override
  String? get path => null;

  @override
  String toString() => 'FsIoException($message)';
}

Future<T> _wrap<T>(Future<T> future) {
  return future.catchError((Object e, StackTrace st) {
    if (e is io.FileSystemException) {
      Error.throwWithStackTrace(_IoFileSystemException(e), st);
    } else if (e is fs.FileSystemException) {
      Error.throwWithStackTrace(e, st);
    } else {
      Error.throwWithStackTrace(
          _FileSystemExceptionIoDefault('error ${e.toString()}'), st);
    }
  });
}

/// File system io implementation.
class FileSystemIo implements fs.FileSystem {
  /// Root path.
  final String? rootPath;

  /// get a path in absolute format.
  String absolute(String path) {
    if (rootPath != null) {
      return normalize(path);
    } else {
      return p.absolute(normalize(path));
    }
  }

  String _normalizeWithRoot(String path) {
    if (rootPath != null) {
      return normalize(join(rootPath!, path));
    } else {
      return normalize(path);
    }
  }

  /// File system io implementation.
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
  Future<bool> isFile(String path) async =>
      io.FileSystemEntity.isFileSync(_normalizeWithRoot(path));

  @override
  Future<bool> isDirectory(String path) async =>
      io.FileSystemEntity.isDirectorySync(_normalizeWithRoot(path));

  @override
  Future<fs.FileSystemEntityType> type(String path,
          {bool followLinks = true}) async =>
      fsFileType(io.FileSystemEntity.typeSync(_normalizeWithRoot(path),
          followLinks: true));

  @override
  DirectoryIo get currentDirectory {
    if (rootPath != null) {
      return directory('.') as DirectoryIo;
    } else {
      // post nnbd...
      return directory('.') as DirectoryIo;
    }
  }

  @override
  FileIo get scriptFile => file(io.Platform.script.toFilePath()) as FileIo;

  @override
  String toString() => 'io';
}

/// File system entity io implementation.
abstract class FileSystemEntityIo implements fs.FileSystemEntity {
  final FileSystemIo _fs;

  @override
  final String path;

  /// The native entity.
  late io.FileSystemEntity ioFileSystemEntity;

  /// File system entity io implementation.
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

  /// io file system.
  FileSystemIo get fileSystemIo => fileSystem as FileSystemIo;
}

/// Directory io implementation.
class DirectoryIo extends FileSystemEntityIo implements fs.Directory {
  /// native directory.
  io.Directory get ioDir => ioFileSystemEntity as io.Directory;

  /// Creates a [DirectoryIo] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [DirectoryIo.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  DirectoryIo(FileSystemIo fs, String path) : super(fs, path) {
    ioFileSystemEntity = io.Directory(fileSystemIo._normalizeWithRoot(path));
  }

  @override
  Future<DirectoryIo> create({bool recursive = false}) //
      =>
      _wrap(ioDir.create(recursive: recursive))
          .then((io.Directory ioDir) => this);

  @override
  Future<fs.FileSystemEntity> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(fileSystemIo._normalizeWithRoot(path)))
          .then((io.FileSystemEntity ioFileSystemEntity) =>
              DirectoryIo(fileSystemIo, newPath));

  @override
  String toString() => "DirectoryIo: '$path'";
}

/// File io implementation.
class FileIo extends FileSystemEntityIo implements fs.File {
  /// native io file.
  io.File get ioFile => ioFileSystemEntity as io.File;

  /// Creates a [FileIo] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [DirectoryIo.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  FileIo(FileSystemIo fs, String path) : super(fs, path) {
    ioFileSystemEntity = io.File(fileSystemIo._normalizeWithRoot(path));
  }

  @override
  Future<fs.File> create({bool recursive = false}) //
      =>
      _wrap(ioFile.create(recursive: recursive)).then((io.File ioFile) => this);

  @override
  Stream<Uint8List> openRead([int? start, int? end]) //
      =>
      intListStreamToUint8ListStream(ioFile.openRead(start, end));

  @override
  fs.IOSink openWrite(
          {fs.FileMode mode = fs.FileMode.write, Encoding encoding = utf8}) //
      =>
      _IoIOSink(ioFile.openWrite(mode: _fileMode(mode), encoding: encoding));

  @override
  Future<FileIo> rename(String newPath) //
      =>
      _wrap(ioFileSystemEntity.rename(fileSystemIo._normalizeWithRoot(newPath)))
          .then((io.FileSystemEntity ioFileSystemEntity) =>
              FileIo(fileSystemIo, newPath));

  @override
  String toString() => "FileIo: '$path'";
}
