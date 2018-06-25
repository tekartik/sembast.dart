library sembast.memory_file_system_impl;

import '../file_system.dart' as fs;

import 'dart:async';
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
      : super(parent, fs.FileSystemEntityType.directory, segment);

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
}

class MemoryFileImpl extends MemoryFileSystemEntityImpl {
  List<String> content;

  MemoryFileImpl(MemoryDirectoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.file, segment);

  Stream<List<int>> openRead() {
    StreamController<List<int>> ctlr = new StreamController(sync: true);
    new Future.sync(() async {
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
      case fs.FileMode.write:
        // erase content
        content = [];
        break;
      case fs.FileMode.append:
        // nothing to do
        if (content == null) {
          content = [];
        }
        break;
      case fs.FileMode.read:
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
}

abstract class MemoryFileSystemEntityImpl {
  // don't access it
  MemoryDirectoryImpl _parent;
  MemoryDirectoryImpl get parent => _parent;

  fs.FileSystemEntityType type;

  MemoryFileSystemEntityImpl(this._parent, this.type, this.segment);

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
  void delete() {
    parent.children.remove(segment);
  }

  Future close() async {
    openCount--;
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
  Future close() async => impl.close();
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
      throw new _MemoryFileSystemException(
          path, "Cannot open file", _noSuchPathError);
    } else {
      return real.close();
    }
  }
}

class MemoryFileSystemImpl {
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

  MemoryFileImpl createFileBySegments(List<String> segments,
      {bool recursive: false}) {
    MemoryFileSystemEntityImpl fileImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (fileImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      MemoryFileSystemEntityImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent =
              createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is MemoryDirectoryImpl) {
        fileImpl = new MemoryFileImpl(parent, segments.last);
        fileImpl.create();
      }
    }
    if (fileImpl is MemoryFileImpl) {
      return fileImpl;
    }
    return null;
  }

  MemoryDirectoryImpl createDirectoryBySegments(List<String> segments,
      {bool recursive: false}) {
    MemoryFileSystemEntityImpl directoryImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (directoryImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      MemoryFileSystemEntityImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent =
              createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is MemoryDirectoryImpl) {
        directoryImpl = new MemoryDirectoryImpl(parent, segments.last);
        directoryImpl.create();
      }
    }
    if (directoryImpl is MemoryDirectoryImpl) {
      return directoryImpl;
    }
    return null;
  }

  Stream<List<int>> openRead(String path) {
    var ctlr = new StreamController<List<int>>(sync: true);
    MemoryFileSystemEntityImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl is MemoryFileImpl) {
      ctlr.addStream(fileImpl.openRead()).then((_) {
        ctlr.close();
      });
    } else {
      ctlr.addError(new _MemoryFileSystemException(
          path, "Cannot open file", _noSuchPathError));
    }
    return ctlr.stream;
  }

  fs.IOSink openWrite(String path, {fs.FileMode mode: fs.FileMode.write}) {
    _TmpSink sink;
    //StreamController ctlr = new StreamController(sync: true);
    MemoryFileSystemEntityImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl == null) {
      // create if needed
      if (mode == fs.FileMode.write || mode == fs.FileMode.append) {
        fileImpl = createFile(path);
      }
    }
    if (fileImpl is MemoryFileImpl) {
      sink = new _TmpSink(path, fileImpl.openWrite(mode));
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

  MemoryFileImpl createFile(String path, {bool recursive: false}) {
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
      throw new _MemoryFileSystemException(
          path, "Deletion failed", _noSuchPathError);
    }
    if (entityImpl != null && (!(entityImpl is MemoryRootDirectoryImpl))) {
      if (entityImpl is MemoryDirectoryImpl) {
        if (recursive != true && (entityImpl.children.isNotEmpty)) {
          throw new _MemoryFileSystemException(path, "Deletion failed",
              new MemoryOSError(39, "Directory is not empty"));
        }
      }
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
      throw new _MemoryFileSystemException(
          path, "Rename failed, destination $newPath exists");
    }
    String segment = segments.last;

    // find dst parent
    MemoryFileSystemEntityImpl newParentImpl =
        getEntityBySegment(getParentSegments(segments));
    if (newParentImpl == null) {
      throw new _MemoryFileSystemException(
          path, "Rename failed, parent destination $newPath does not exist");
    }
    if (newParentImpl is MemoryDirectoryImpl) {
      entityImpl.delete();

      if (entityImpl is MemoryFileImpl) {
        newEntityImpl = new MemoryFileImpl(newParentImpl, segment);
        (newEntityImpl as MemoryFileImpl).content = entityImpl.content;
      } else {
        newEntityImpl = new MemoryDirectoryImpl(newParentImpl, segment);
      }
      newEntityImpl.create();
      return newEntityImpl;
    } else {
      throw new _MemoryFileSystemException(
          path, "Rename failed, parent destination $newPath not a directory");
    }
  }

  MemoryRootDirectoryImpl rootDir = new MemoryRootDirectoryImpl();

  Future<fs.FileSystemEntityType> type(String path, {bool followLinks: true}) {
    return new Future.sync(() {
      MemoryFileSystemEntityImpl impl = getEntity(path);
      if (impl != null) {
        return impl.type;
      }
      return fs.FileSystemEntityType.notFound;
    });
  }

  @override
  String toString() => "memory";
}
