library sembast.memory_file_system;

import '../file_system.dart' as fs;

import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';

final _MemoryFileSystem _fs = new _MemoryFileSystem();
_MemoryFileSystem get memoryFileSystem => _fs;

_IoOSError get _noSuchPathError =>
    new _IoOSError(2, "No such file or directory");

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
  String get message =>
      _message == null ? (osError == null ? null : osError.message) : _message;

  @override
  final String path;

  @override
  String toString() {
    return "FileSystemException: ${message}, path = '${path}' ${osError}";
  }
}

class _MemoryDirectoryImpl extends _MemoryFileSystemEntityImpl {
  Map<String, _MemoryFileSystemEntityImpl> children = {};
  _MemoryDirectoryImpl(_MemoryDirectoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.DIRECTORY, segment);

  _MemoryFileSystemEntityImpl getChild(String segment) {
    _MemoryFileSystemEntityImpl child = children[segment];
    return child;
  }

  _MemoryFileSystemEntityImpl getChildEntityFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    String segment = segments.first;
    _MemoryFileSystemEntityImpl child = getChild(segment);

    if (child == null) {
      return null;
    }

    if (isLastSegment) {
      return child;
    } else {
      if (child is _MemoryDirectoryImpl) {
        return child.getChildEntityFromPath(joinAll(segments.sublist(1)));
      }
    }
    return null;
  }

  _MemoryDirectoryImpl getDirFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    String segment = segments.first;
    _MemoryFileSystemEntityImpl child = getChild(segment);
    if (child == null || (!(child is _MemoryDirectoryImpl))) {
      // create tmp dir object
      child = new _MemoryDirectoryImpl(this, segment);
    }
    if (isLastSegment) {
      return child;
    } else {
      return (child as _MemoryDirectoryImpl)
          .getDirFromPath(joinAll(segments.sublist(1)));
    }
  }

  _MemoryFileImpl getFileFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    if (isLastSegment) {
      String segment = segments.first;
      _MemoryFileSystemEntityImpl child = getChild(segment);
      if (child == null || (!(child is _MemoryFileImpl))) {
        // create tmp dir object
        child = new _MemoryFileImpl(this, segment);
      }
      return child;
    }
    return getDirFromPath(dirname(path)).getFileFromPath(segments.last);
  }

  @override
  String toString() {
    return "memDir:${path}";
  }

  @override
  _MemoryDirectoryImpl createSync(bool recursive) {
    _MemoryFileSystemEntityImpl impl = existingImpl;
    if (!_checkFileExists(impl)) {
      if (!recursive) {
        throw new _MemoryFileSystemException(
            path, "Creation failed", _noSuchPathError);
      } else {
        _MemoryDirectoryImpl parentImpl = _parent.createSync(recursive);
        if (impl == null) {
          // set parent
          __parent = parentImpl;
          impl = this;
        }
      }
    }
    if (impl is _MemoryDirectoryImpl) {
      impl.implSetExists(true);
    } else {
      throw 'not a dir';
    }
    return this;
  }
}

class _MemoryFileImpl extends _MemoryFileSystemEntityImpl {
  List<String> content;

  _MemoryFileImpl(_MemoryDirectoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.FILE, segment);

  Stream<List<int>> openRead() {
    var impl = existingImpl;
    StreamController ctlr = new StreamController(sync: true);
    new Future.sync(() async {
      if (!_checkExists()) {
        ctlr.addError(new _MemoryFileSystemException(
            path, "Cannot open file", _noSuchPathError));
      } else {
        impl.openCount++;
        if (impl.content != null) {
          impl.content.forEach((String line) {
            ctlr.add(line.codeUnits);
            ctlr.add('\n'.codeUnits);
          });
        }
        try {
          await close();
        } catch (e) {
          ctlr.addError(e);
        }
      }
      ctlr.close();
    });
    return ctlr.stream;
  }

  _MemoryIOSink openWrite(fs.FileMode mode) {
    var impl = existingImpl;
    // delay the error
    if (impl == null) {
      impl = this;
    }
    _MemoryIOSink sink = new _MemoryIOSink(impl);
    if (impl != null) {
      impl.openCount++;
      switch (mode) {
        case fs.FileMode.WRITE:
          // erase content
          impl.content = [];
          break;
        case fs.FileMode.APPEND:
          // nothing to do
          break;
        case fs.FileMode.READ:
          throw 'mode READ not support for openWrite ${this}';
        default:
          throw null;
      }
    }
    return sink;
  }

  //
  // IOSink implementation
  //
  void append(String line) {
    var impl = existingImpl;
    if (impl.closed) {
      throw "${this} already closed";
    }
    impl.content.add(line);
  }

  @override
  String toString() {
    return "memFile:${path}";
  }

  _MemoryFileImpl createSync(bool recursive) {
    var impl = existingImpl;
    if (_checkFileExists(impl)) {
      throw 'cannot create ${this}. already exists';
    }
    _MemoryDirectoryImpl parentImpl = _parent.createSync(recursive);
    if (impl == null) {
      // set parent
      __parent = parentImpl;
      impl = this;
    }
    if (impl is _MemoryFileImpl) {
      impl.content = [];
      impl.implSetExists(true);
    } else {
      throw 'not a file';
    }
    return this;
  }
}

bool _checkFileExists(_MemoryFileSystemEntityImpl impl) {
  if (impl == null) {
    return false;
  }
  return impl._exists;
}

abstract class _MemoryFileSystemEntityImpl {
  // don't access it
  _MemoryDirectoryImpl __parent;
  _MemoryDirectoryImpl get _parent {
    var impl = existingImpl;
    if (impl != null && impl != this) {
      __parent = impl._parent;
    }
    return __parent;
  }

  fs.FileSystemEntityType _type;

  bool get isRootDir => this == _fs.rootDir;

  implSetExists(bool exists_) {
    if (!isRootDir) {
      if (exists_) {
        // make it exists
        _parent.children[segment] = this;
        _exists = true;
      } else {
        _parent.children.remove(segment);
        _exists = false;
      }
    }
  }

  _MemoryFileSystemEntityImpl(this.__parent, this._type, this.segment);
  bool _exists = false;

  _MemoryFileSystemEntityImpl get existingImpl {
    if (isRootDir) {
      return this;
    } else {
      // check save __parent
      _MemoryFileSystemEntityImpl _parentImpl = __parent.existingImpl;
      if (_parentImpl is _MemoryDirectoryImpl) {
        return _parentImpl.children[segment];
      }
      return null;
    }
  }

  Future<bool> exists() {
    return new Future.sync(() {
      _MemoryFileSystemEntityImpl impl = existingImpl;
      return _checkFileExists(impl);
    });
  }

  bool _checkExists() {
    return _checkFileExists(existingImpl);
  }

  String segment;
  String get path {
    if (this == _fs.rootDir) {
      return "/";
    } else {
      return join(_parent.path, segment);
    }
  }

  int openCount = 0;
  bool get closed => (openCount == 0);

  //
  // File implementation
  //
  Future<_MemoryFileSystemEntityImpl> delete() {
    return new Future.sync(() {
      if (isRootDir) {
        throw new _MemoryFileSystemException(path, "Deletion failed");
      }
      _MemoryFileSystemEntityImpl impl = existingImpl;
      if (!_checkFileExists(impl)) {
        throw new _MemoryFileSystemException(
            path, "Deletion failed", _noSuchPathError);
      }
      // remove from parent
      impl._parent.children.remove(segment);
      impl._exists = false;
    });
  }

  // base implementation
  Future<_MemoryFileSystemEntityImpl> rename(String newPath) {
    return new Future.sync(() {
      if (isRootDir) {
        throw new _MemoryFileSystemException(path, "Rename failed");
      }
      _MemoryFileSystemEntityImpl impl = existingImpl;
      if (!_checkFileExists(impl)) {
        throw new _MemoryFileSystemException(
            path, "Rename failed", _noSuchPathError);
      }
      // remove from parent
      impl._parent.children.remove(segment);
      impl._exists = false;

      String newSegment = basename(newPath);
      if (impl is _MemoryFileImpl) {
        _MemoryFileImpl newImpl = new _MemoryFileImpl(impl._parent, newSegment);

        newImpl.content = impl.content;

        // re-add
        newImpl.implSetExists(true);

        return newImpl;
      } else {
        throw 'not supported yet';
      }
    });
  }

  _MemoryFileSystemEntityImpl createSync(bool recursive);
//  _MemoryFileSystemEntityImpl createSync(bool recursive) {
//    _MemoryFileSystemEntityImpl impl = existingImpl;
//    if (!_checkExists(impl)) {
//      if (!recursive) {
//        throw new _MemoryFileSystemException(path, "Creation failed", _noSuchPathError);
//      } else {
//        _parent.createSync(recursive);
//        impl = existingImpl;
//      }
//    }
//    //return implCreate(recursive);
//
//  }

  Future<_MemoryFileSystemEntityImpl> create(bool recursive) {
    return new Future.sync(() {
      return createSync(recursive);
    });
  }

  // Just create the last segment
  //_MemoryFileSystemEntityImpl implCreate();
//  Future<_MemoryFileSystemEntityImpl> createFile() {
//    return new Future.sync(() {
//      if (_exists) {
//        throw 'cannot create ${this}. already exists';
//      }
//      content = [];
//      _exists = true;
//    });
//  }

  Future close() {
    return new Future.sync(() {
      if (!_checkExists()) {
        throw new _MemoryFileSystemException(
            path, "Cannot close file", _noSuchPathError);
      }
      openCount--;
    });
  }

  @override
  String toString() {
    return "memEntity:${path}";
  }
}

class _MemoryIOSink implements fs.IOSink {
  _MemoryFileImpl impl;
  _MemoryIOSink(this.impl);

  @override
  void writeln([Object obj = ""]) => impl.append(obj.toString());

  @override
  Future close() => impl.close();
}

class _MemoryFileSystem implements fs.FileSystem {
  _MemoryFileSystem() {
    rootDir._exists = true;
  }

  _MemoryDirectoryImpl rootDir = new _MemoryDirectoryImpl(null, null);

  _MemoryDirectoryImpl getDirFromPath(String path) {
    if (path == null) {
      return rootDir;
    }
    return rootDir.getDirFromPath(path);
  }

  @override
  fs.File newFile(String path) {
    return new _MemoryFile(rootDir.getFileFromPath(path));
  }

  @override
  fs.Directory newDirectory(String path) {
    return new _MemoryDirectory(getDirFromPath(path));
  }

  @override
  Future<bool> isFile(String path) {
    return type(path, followLinks: true).then((fs.FileSystemEntityType type) {
      return type == fs.FileSystemEntityType.FILE;
    });
  }

  @override
  Future<bool> isDirectory(String path) {
    return type(path, followLinks: true).then((fs.FileSystemEntityType type) {
      return type == fs.FileSystemEntityType.DIRECTORY;
    });
  }

  @override
  Future<fs.FileSystemEntityType> type(String path, {bool followLinks: true}) {
    return new Future.sync(() {
      _MemoryFileSystemEntityImpl impl = rootDir.getChildEntityFromPath(path);
      if (impl != null) {
        return impl._type;
      }
      return fs.FileSystemEntityType.NOT_FOUND;
    });
  }

  @override
  _MemoryDirectory get currentDirectory => newDirectory("current");

  @override
  _MemoryFile get scriptFile => null;

  @override
  String toString() => "memory";
}

abstract class _MemoryFileSystemEntity implements fs.FileSystemEntity {
  _MemoryFileSystemEntityImpl impl;

  @override
  Future<bool> exists() => impl.exists();

  // don't care about recursive
  @override
  Future<fs.FileSystemEntity> delete({bool recursive: false}) //
      =>
      impl.delete().then((_MemoryFileSystemEntityImpl impl) => this);

  @override
  String get path => impl.path;

  @override
  String toString() => impl.toString();
}

class _MemoryDirectory extends _MemoryFileSystemEntity implements fs.Directory {
  _MemoryDirectoryImpl get dirImpl => impl;
  _MemoryDirectory(_MemoryDirectoryImpl impl) {
    this.impl = impl;
  }

  @override Future<_MemoryDirectory> create({bool recursive: false}) =>
      dirImpl.create(recursive).then((_) => this);

  @override
  Future<fs.FileSystemEntity> rename(String newPath) //
      =>
      impl.rename(newPath).then(
          (_MemoryFileSystemEntityImpl impl) => new _MemoryDirectory(impl));
}

class _MemoryFile extends _MemoryFileSystemEntity implements fs.File {
  _MemoryFileImpl get fileImpl => impl;

  _MemoryFile(_MemoryFileImpl impl) {
    this.impl = impl;
  }

  // don't care about recursive
  @override
  Future<fs.File> create({bool recursive: false}) //
      =>
      fileImpl
          .create(recursive)
          .then((_MemoryFileSystemEntityImpl impl) => this);

  // don't care about start end
  @override
  Stream<List<int>> openRead([int start, int end]) //
      =>
      fileImpl.openRead();

  // don't care about encoding - assume UTF8
  @override
  fs.IOSink openWrite(
          {fs.FileMode mode: fs.FileMode.WRITE, Encoding encoding: UTF8}) //
      =>
      fileImpl.openWrite(mode);

  @override
  Future<fs.FileSystemEntity> rename(String newPath) //
      =>
      impl
          .rename(newPath)
          .then((_MemoryFileSystemEntityImpl impl) => new _MemoryFile(impl));
}
