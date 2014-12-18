library sembast.memory_file_system;

import '../file_system.dart' as fs;

import 'dart:async';
import 'dart:convert';

final _MemoryFileSystem _fs = new _MemoryFileSystem();
_MemoryFileSystem get memoryFileSystem => _fs;

_IoOSError get _noSuchPathError => new _IoOSError(2, "No such file or directory");

class _IoOSError implements fs.OSError {
  _IoOSError(this.errorCode, this.message);
  final int errorCode;
  final String message;

  @override
  String toString() {
    return "(OS Error: ${message}, errno = ${errorCode})";
  }
}

class _MemoryFileSystemException implements fs.FileSystemException {

  _MemoryFileSystemException(this.path, [this._message, this.osError]);

  String _message;
  @override
  final _IoOSError osError;

  @override
  String get message => _message == null ? (osError == null ? null : osError.message) : _message;

  @override
  final String path;

  @override
  String toString() {
    return "FileSystemException: ${message}, path = '${path}' ${osError}";
  }
}

class _MemoryImpl {
  _MemoryImpl(this.path);
  bool _exists = false;
  Future<bool> exists() => new Future.value(_exists);
  String path;
  int openCount = 0;
  bool get closed => (openCount == 0);
  List<String> content;

  //
  // File implementation
  //
  Future<_MemoryImpl> delete() {
    return new Future.sync(() {
      if (!_exists) {
        throw new _MemoryFileSystemException(path, "Deletion failed", _noSuchPathError);
      }
      _exists = false;
    });
  }

  Future<_MemoryImpl> create() {
    return new Future.sync(() {
      if (_exists) {
        throw 'cannot create ${this}. already exists';
      }
      content = [];
      _exists = true;
    });
  }

  Stream<List<int>> openRead() {
    StreamController ctlr = new StreamController(sync: true);
    new Future.sync(() {
      content.forEach((String line) {
        ctlr.add(line.codeUnits);
      });
    });
    return ctlr.stream;
  }

  _MemoryIOSink openWrite(fs.FileMode mode) {
    _MemoryIOSink sink = new _MemoryIOSink(this);
    switch (mode) {
      case fs.FileMode.WRITE:
        // erase content
        content = [];
        break;
      case fs.FileMode.APPEND:
        // nothing to do
        break;
      case fs.FileMode.READ:
        throw 'mode READ not support for openWrite ${this}';
      default:
        throw null;
    }
    return sink;
  }


  //
  // IOSink implementation
  //
  void append(String line) {
    if (closed) {
      throw "${this} already closed";
    }
    content.add(line);
  }

  Future close() {
    return new Future.sync(() => openCount--);
  }

  @override
  String toString() {
    return "memFile:${path}";
  }
}

class _MemoryIOSink implements fs.IOSink {
  _MemoryImpl impl;
  _MemoryIOSink(this.impl);

  @override
  void writeln([Object obj = ""]) => impl.append(obj.toString());

  @override
  Future close() => impl.close();

}

class _MemoryFileSystem implements fs.FileSystem {

  Map<String, _MemoryImpl> impls = {};

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
    return new Future.sync(() {
      _MemoryImpl impl = impls[path];
      if (impl != null) {
        return impl.exists();
      }
      return false;
    });
  }
}

class _MemoryFileSystemEntity implements fs.FileSystemEntity {
  _MemoryImpl impl;

  @override
  Future<bool> exists() => impl.exists();

  // don't care about recursive
  @override
  Future<fs.FileSystemEntity> delete({bool recursive: false}) //
  => impl.delete().then((_MemoryImpl impl) => this);

  @override
  String get path => impl.path;
}

class _MemoryDirectory extends _MemoryFileSystemEntity implements fs.Directory {

  _MemoryDirectory(String path) {
    impl = new _MemoryImpl(path);
  }
}

class _MemoryFile extends _MemoryFileSystemEntity implements fs.File {

  _MemoryFile(String path) {
    impl = new _MemoryImpl(path);
  }

  // don't care about recursive
  @override
  Future<fs.File> create({bool recursive: false}) //
  => impl.create().then((_MemoryImpl impl) => this);

  // don't care about start end
  @override
  Stream<List<int>> openRead([int start, int end]) //
  => impl.openRead();

  // don't care about encoding - assume UTF8
  @override
  fs.IOSink openWrite({fs.FileMode mode: fs.FileMode.WRITE, Encoding encoding: UTF8}) //
  => impl.openWrite(mode);
}
