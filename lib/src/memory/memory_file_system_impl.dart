library sembast.memory_file_system_impl;

import '../file_system.dart' as fs;

import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';

MemoryOSError get _noSuchPathError =>
new MemoryOSError(2, "No such file or directory");

class MemoryOSError implements fs.OSError {
  MemoryOSError(this.errorCode, this.message);
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
  final MemoryOSError osError;

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

class MemoryDirectoryImpl extends MemoryFileSystemEntityImpl {
  Map<String, MemoryFileSystemEntityImpl> children = {};
  MemoryDirectoryImpl(MemoryDirectoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.DIRECTORY, segment);

  MemoryFileSystemEntityImpl getChild(String segment) {
    MemoryFileSystemEntityImpl child = children[segment];
    return child;
  }

  MemoryFileSystemEntityImpl getChildEntityFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    String segment = segments.first;
    MemoryFileSystemEntityImpl child = getChild(segment);

    if (child == null) {
      return null;
    }

    if (isLastSegment) {
      return child;
    } else {
      if (child is MemoryDirectoryImpl) {
        return child.getChildEntityFromPath(joinAll(segments.sublist(1)));
      }
    }
    return null;
  }

  MemoryDirectoryImpl getDirFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    String segment = segments.first;
    MemoryFileSystemEntityImpl child = getChild(segment);
    if (child == null || (!(child is MemoryDirectoryImpl))) {
      // create tmp dir object
      child = new MemoryDirectoryImpl(this, segment);
    }
    if (isLastSegment) {
      return child;
    } else {
      return (child as MemoryDirectoryImpl)
          .getDirFromPath(joinAll(segments.sublist(1)));
    }
  }

  MemoryFileImpl getFileFromPath(String path) {
    List<String> segments = split(path);
    bool isLastSegment = (segments.length == 1);
    if (isLastSegment) {
      String segment = segments.first;
      MemoryFileSystemEntityImpl child = getChild(segment);
      if (child == null || (!(child is MemoryFileImpl))) {
        // create tmp dir object
        child = new MemoryFileImpl(this, segment);
      }
      return child;
    }
    return getDirFromPath(dirname(path)).getFileFromPath(segments.last);
  }


  MemoryFileSystemEntityImpl getEntity(List<String> segments) {
    if (segments.isEmpty) {
      return this;
    }
    MemoryFileSystemEntityImpl child = children[segments.first];
    if (segments.length == 1) {
      return child;
    }
    if (child is MemoryDirectoryImpl) {
      return child.getEntity(segments.sublist(1));
    }
    return null;
  }

  @override
  String toString() {
    return "memDir:${path}";
  }

  @override
  MemoryDirectoryImpl createSync(bool recursive) {
    MemoryFileSystemEntityImpl impl = existingImpl;
    if (!_checkFileExists(impl)) {
      if (!recursive) {
        throw new _MemoryFileSystemException(
            path, "Creation failed", _noSuchPathError);
      } else {
        MemoryDirectoryImpl parentImpl = parent.createSync(recursive);
        if (impl == null) {
          // set parent
          _parent = parentImpl;
          impl = this;
        }
      }
    }
    if (impl is MemoryDirectoryImpl) {
      impl.implSetExists(true);
    } else {
      throw 'not a dir';
    }
    return this;
  }
}

class MemoryFileImpl extends MemoryFileSystemEntityImpl {
  List<String> content;

  MemoryFileImpl(MemoryDirectoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.FILE, segment);

  Stream<List<int>> openRead() {

    StreamController ctlr = new StreamController(sync: true);
    new Future.sync(() async {
      /*
      if (!_checkExists()) {
        ctlr.addError(new _MemoryFileSystemException(
            path, "Cannot open file", _noSuchPathError));
      } else {
      */
        openCount++;
        if (content != null) {
          content.forEach((String line) {
            ctlr.add(line.codeUnits);
            ctlr.add('\n'.codeUnits);
          });
        }
        try {
          await close();
        } catch (e) {
          ctlr.addError(e);
        }

      ctlr.close();
    });
    return ctlr.stream;
  }

  _MemoryIOSink openWrite(fs.FileMode mode) {
    // delay the error

    _MemoryIOSink sink = new _MemoryIOSink(this);
openCount++;
      switch (mode) {
        case fs.FileMode.WRITE:
          // erase content
          content = [];
          break;
        case fs.FileMode.APPEND:
          // nothing to do
        if (content == null) {
          content = [];
        }
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

  @override
  String toString() {
    return "memFile:${path}";
  }

  MemoryFileImpl createSync(bool recursive) {
    var impl = existingImpl;
    if (_checkFileExists(impl)) {
      // ok to create
      // throw 'cannot create ${this}. already exists';
      return impl;
    }
    MemoryDirectoryImpl parentImpl = parent.createSync(recursive);
    if (impl == null) {
      // set parent
      _parent = parentImpl;
      impl = this;
    }
    if (impl is MemoryFileImpl) {
      impl.content = [];
      impl.implSetExists(true);
    } else {
      throw 'not a file';
    }
    return this;
  }
}

bool _checkFileExists(MemoryFileSystemEntityImpl impl) {
  if (impl == null) {
    return false;
  }
  return impl._exists;
}

abstract class MemoryFileSystemEntityImpl {
  // don't access it
  MemoryDirectoryImpl _parent;
  MemoryDirectoryImpl get parent => _parent;

  fs.FileSystemEntityType type;

  implSetExists(bool exists_) {
    if (!isRootDir) {
      if (exists_) {
        // make it exists
        parent.children[segment] = this;
        _exists = true;
      } else {
        parent.children.remove(segment);
        _exists = false;
      }
    }
  }

  MemoryFileSystemEntityImpl(this._parent, this.type, this.segment);
  bool _exists = false;

  /*
  MemoryFileSystemEntityImpl get existingImpl {
    if (isRootDir) {
      return this;
    } else {
      // check save __parent
      MemoryFileSystemEntityImpl _parentImpl = _parent.existingImpl;
      if (_parentImpl is MemoryDirectoryImpl) {
        return _parentImpl.children[segment];
      }
      return null;
    }
  }*/

  Future<bool> exists() {
    return new Future.sync(() {
      MemoryFileSystemEntityImpl impl = existingImpl;
      return _checkFileExists(impl);
    });
  }

  @deprecated
  bool _checkExists() {
    return _checkFileExists(this);
  }

  String segment;

  // Build path
  String get path => join(parent.path, segment);

  int openCount = 0;
  bool get closed => (openCount == 0);

  // Set in the parent
  create() {
    parent.children[segment] = this;
  }
  //
  // File implementation
  //
  MemoryFileSystemEntityImpl delete() {
      /*
      if (isRootDir) {
        throw new _MemoryFileSystemException(path, "Deletion failed");
      }
      */
    /*
      MemoryFileSystemEntityImpl impl = existingImpl;
      if (!_checkFileExists(impl)) {
        throw new _MemoryFileSystemException(
            path, "Deletion failed", _noSuchPathError);
      }
      */
      // remove from parent
      parent.children.remove(segment);
    //  impl._exists = false;

  }



  MemoryFileSystemEntityImpl createSync(bool recursive);
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
      /*
      if (!_checkExists()) {
        throw new _MemoryFileSystemException(
            path, "Cannot close file", _noSuchPathError);
      }
      */
      openCount--;
    });
  }

  @override
  String toString() {
    return "memEntity:${path}";
  }
}

class _MemoryIOSink implements fs.IOSink {
  MemoryFileImpl impl;
  _MemoryIOSink(this.impl);

  @override
  void writeln([Object obj = ""]) => impl.append(obj.toString());

  @override
  Future close() => impl.close();
}

class MemoryRootDirectoryImpl extends MemoryDirectoryImpl {
  MemoryRootDirectoryImpl() : super(null, separator);

  @override
  String get path => segment;
}

class _TmpSink implements fs.IOSink {
  String path;
  _MemoryIOSink real;
  _TmpSink(this.path, this.real);

  @override
  void writeln([Object obj = ""]) => real.writeln(obj);

  @override
  Future close() {
    if (real == null) {
      throw new _MemoryFileSystemException(path, "Cannot open file", _noSuchPathError);
    } else {
      return real.close();
    }
  }
}

class MemoryFileSystemImpl  {

  // Must be absolute
  // /current by default which might not exists!
  String currentPath;

  MemoryFileSystemImpl() {
    //rootDir._exists = true;
    currentPath = join(rootDir.path, "current");
  }

  List<String> getSegments(String path) {
    List<String> segments = split(path);
    if (!isAbsolute(path)) {
      segments.insertAll(0, split(currentPath));
    }
    return segments;
  }
  MemoryFileSystemEntityImpl getEntity(String path) {
    // Get the segments list

    return getEntityBySegment(getSegments(path));
  }

  List<String> getParentSegments(List<String> segments) {
    return segments.sublist(0, segments.length - 1);

  }
  MemoryFileSystemEntityImpl getEntityBySegment(List<String> segments) {
    if (segments.first == rootDir.path) {
      return rootDir.getEntity(segments.sublist(1));
    }
    return null;
  }

  MemoryFileImpl createFileBySegments(List<String> segments, {bool recursive: false}) {

    MemoryFileSystemEntityImpl fileImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (fileImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      MemoryFileSystemEntityImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent = createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is MemoryDirectoryImpl) {
        fileImpl = new MemoryFileImpl(parent, segments.last);
        fileImpl.create();
      }
    }
    if (fileImpl is MemoryFileImpl){
      return fileImpl;
    }
    return null;
  }

  MemoryDirectoryImpl createDirectoryBySegments(List<String> segments, {bool recursive: false}) {

    MemoryFileSystemEntityImpl directoryImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (directoryImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      MemoryFileSystemEntityImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent = createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is MemoryDirectoryImpl) {
        directoryImpl = new MemoryDirectoryImpl(parent, segments.last);
        directoryImpl.create();
      }
    }
      if (directoryImpl is MemoryDirectoryImpl){
      return directoryImpl;
    }
    return null;
  }

  Stream<List<int>> openRead(String path) {
    StreamController ctlr = new StreamController(sync: true);
    MemoryFileSystemEntityImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl is MemoryFileImpl) {
      ctlr.addStream((fileImpl as MemoryFileImpl).openRead()).then((_) {
        ctlr.close();
      });
    } else {
      ctlr.addError(new  _MemoryFileSystemException(path, "Cannot open file", _noSuchPathError));
    }
    return ctlr.stream;
  }

  fs.IOSink openWrite(String path, {fs.FileMode mode: fs.FileMode.WRITE}) {
    _TmpSink sink;
    StreamController ctlr = new StreamController(sync: true);
    MemoryFileSystemEntityImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl == null) {
      // create if needed
      if (mode == fs.FileMode.WRITE || mode == fs.FileMode.APPEND) {
        fileImpl = createFile(path);
      }
    }
  if (fileImpl is MemoryFileImpl) {
      sink = new _TmpSink(path, (fileImpl as MemoryFileImpl).openWrite(mode));
    } else {
      sink = new _TmpSink(path, null);
      //ctlr.addError(new  _MemoryFileSystemException(path, "Cannot open file", _noSuchPathError));
    }
    return sink;
  }

  createDirectory(String path, {bool recursive: false}) {
    // Go up one by one
    List<String> segments = getSegments(path);
    return createDirectoryBySegments(segments, recursive: recursive);
  }

  createFile(String path, {bool recursive: false}) {
    // Go up one by one
    List<String> segments = getSegments(path);

    return createFileBySegments(segments, recursive: recursive);
  }

  bool exists(String path) {
    MemoryFileSystemEntityImpl entityImpl = getEntity(path);
    if (entityImpl != null) {
      return true;
    }
    return false;
  }

  void delete(String path, {bool recursive: false}) {
    MemoryFileSystemEntityImpl entityImpl = getEntity(path);
    if (entityImpl == null) {
      throw new _MemoryFileSystemException(path, "Deletion failed", _noSuchPathError);
    }
    if (entityImpl != null && (!(entityImpl is MemoryRootDirectoryImpl))) {
      if (entityImpl is MemoryDirectoryImpl) {
        if (recursive != true && ((entityImpl as MemoryDirectoryImpl).children.isNotEmpty)) {
          throw new _MemoryFileSystemException(path, "Deletion failed", new MemoryOSError(39, "Directory is not empty"));
        }
      }
      /*else {
        throw new MemoryOSError(100, "not a directory");
      }
      */
      entityImpl.delete();
    }
  }

  // base implementation
  MemoryFileSystemEntityImpl rename(String path, String newPath) {
    MemoryFileSystemEntityImpl entityImpl = getEntity(path);
    if (entityImpl == null) {
      throw new _MemoryFileSystemException(
          path, "Rename failed", _noSuchPathError);
    }
      if (entityImpl is MemoryRootDirectoryImpl) {
        throw new _MemoryFileSystemException(path, "Rename failed at root");
      }

    List<String> segments = getSegments(newPath);
    // make sure dest does not exist
    MemoryFileSystemEntityImpl newEntityImpl = getEntityBySegment(segments);
    if (newEntityImpl != null) {
      throw new _MemoryFileSystemException(path, "Rename failed, destination $newPath exists");
    }
    String segment = segments.last;

    // find dst parent
    MemoryFileSystemEntityImpl newParentImpl = getEntityBySegment(getParentSegments(segments));
    if (newParentImpl == null) {
      throw new _MemoryFileSystemException(path, "Rename failed, parent destination $newPat does not exist");
    }
    if (newParentImpl is MemoryDirectoryImpl) {
      entityImpl.delete();

      if (entityImpl is MemoryFileImpl) {
        newEntityImpl = new MemoryFileImpl(newParentImpl, segment);
        (newEntityImpl as MemoryFileImpl).content = (entityImpl as MemoryFileImpl).content;
      } else {
        newEntityImpl = new MemoryDirectoryImpl(newParentImpl, segment);
      }
      newEntityImpl.create();
      return newEntityImpl;

    } else {
      throw new _MemoryFileSystemException(path, "Rename failed, parent destination $newPat not a directory");
    }
/*
      // remove from parent
      impl.parent.children.remove(segment);
      impl._exists = false;

      String newSegment = basename(newPath);
      if (impl is MemoryFileImpl) {
        MemoryFileImpl newImpl = new MemoryFileImpl(impl.parent, newSegment);

        newImpl.content = impl.content;

        // re-add
        newImpl.implSetExists(true);

        return newImpl;
      } else {
        throw 'not supported yet';
      }
    });
    */
  }

  MemoryRootDirectoryImpl rootDir = new MemoryRootDirectoryImpl();

  MemoryDirectoryImpl getDirFromPath(String path) {
    if (path == null) {
      return rootDir;
    }
    return rootDir.getDirFromPath(path);
  }
/*
  @override
  fs.File newFile(String path) {
    return new _MemoryFile(rootDir.getFileFromPath(path));
  }

  @override
  fs.Directory newDirectory(String path) {
    return new _MemoryDirectory(path));
  }
  */

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
      MemoryFileSystemEntityImpl impl = rootDir.getChildEntityFromPath(path);
      if (impl != null) {
        return impl.type;
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
