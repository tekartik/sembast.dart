library sembast.memory_file_system_impl;

import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sembast/src/file_system.dart' as fs;

OSErrorMemory get _noSuchPathError =>
    OSErrorMemory(2, "No such file or directory");

/// OS memory error.
class OSErrorMemory implements fs.OSError {
  /// OS memory error.
  OSErrorMemory(this.errorCode, this.message);

  @override
  final int errorCode;
  @override
  final String message;

  @override
  String toString() {
    return "(OS Error: ${message}, errno = ${errorCode})";
  }
}

/// Memory exception.
class FileSystemExceptionMemory implements fs.FileSystemException {
  /// Memory exception.
  FileSystemExceptionMemory(this.path, [this._message, this.osError]);

  String _message;
  @override
  final OSErrorMemory osError;

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

/// Memory implementation.
class DirectoryMemoryImpl extends FileSystemEntityMemoryImpl {
  /// children.
  Map<String, FileSystemEntityMemoryImpl> children = {};

  /// Memory implementation.
  DirectoryMemoryImpl(DirectoryMemoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.directory, segment);

  /// get a file system entity.
  FileSystemEntityMemoryImpl getEntity(List<String> segments) {
    if (segments.isEmpty) {
      return this;
    }
    FileSystemEntityMemoryImpl child = children[segments.first];
    if (segments.length == 1) {
      return child;
    }
    if (child is DirectoryMemoryImpl) {
      return child.getEntity(segments.sublist(1));
    }
    return null;
  }

  @override
  String toString() {
    return "memDir:${path}";
  }
}

/// In memory file.
class FileMemoryImpl extends FileSystemEntityMemoryImpl {
  /// Content.
  List<String> content;

  /// In memory file.
  FileMemoryImpl(DirectoryMemoryImpl parent, String segment)
      : super(parent, fs.FileSystemEntityType.file, segment);

  /// Open for read.
  Stream<Uint8List> openRead() {
    StreamController<Uint8List> ctlr = StreamController(sync: true);
    Future.sync(() async {
      openCount++;
      if (content != null) {
        content.forEach((String line) {
          ctlr.add(Uint8List.fromList(line.codeUnits));
          ctlr.add(Uint8List.fromList('\n'.codeUnits));
        });
      }
      try {
        await close();
      } catch (e) {
        ctlr.addError(e);
      }

      await ctlr.close();
    });
    return ctlr.stream;
  }

  /// Open for write.
  IOSinkMemory openWrite(fs.FileMode mode) {
    // delay the error

    IOSinkMemory sink = IOSinkMemory(this);
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
  /// Append a line.
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

/// File system entity.
abstract class FileSystemEntityMemoryImpl {
  // don't access it
  DirectoryMemoryImpl _parent;

  /// Parent.
  DirectoryMemoryImpl get parent => _parent;

  /// Type.
  fs.FileSystemEntityType type;

  /// File system entity.
  FileSystemEntityMemoryImpl(this._parent, this.type, this.segment);

  /// Last segment
  String segment;

  /// Build path
  String get path => join(parent.path, segment);

  /// open count.
  int openCount = 0;

  /// True if closed.
  bool get closed => (openCount == 0);

  /// Creates.
  ///
  /// Set in the parent
  void create() {
    parent.children[segment] = this;
  }

  //
  // File implementation
  //
  /// Delete a file.
  void delete() {
    parent.children.remove(segment);
  }

  /// Close a file.
  Future close() async {
    openCount--;
  }

  @override
  String toString() {
    return "memEntity:${path}";
  }
}

/// In memory io sink.
class IOSinkMemory implements fs.IOSink {
  /// The file.
  FileMemoryImpl impl;

  /// In memory io sink.
  IOSinkMemory(this.impl);

  @override
  void writeln([Object obj = ""]) => impl.append(obj.toString());

  @override
  Future close() async => impl.close();
}

/// Root directory.
class RootDirectoryMemoryImpl extends DirectoryMemoryImpl {
  /// Root directory.
  RootDirectoryMemoryImpl() : super(null, separator);

  @override
  String get path => segment;
}

class _TmpSink implements fs.IOSink {
  String path;
  IOSinkMemory real;

  _TmpSink(this.path, this.real);

  @override
  void writeln([Object obj = ""]) => real.writeln(obj);

  @override
  Future close() {
    if (real == null) {
      throw FileSystemExceptionMemory(
          path, "Cannot open file", _noSuchPathError);
    } else {
      return real.close();
    }
  }
}

/// In memory file system.
class FileSystemMemoryImpl {
  // Must be absolute
  // /current by default which might not exists!
  /// current path.
  String currentPath;

  /// In memory file system.
  FileSystemMemoryImpl() {
    //rootDir._exists = true;
    currentPath = join(rootDir.path, "current");
  }

  /// Get the segements from a path.
  List<String> getSegments(String path) {
    List<String> segments = split(path);
    if (!isAbsolute(path)) {
      segments.insertAll(0, split(currentPath));
    }
    return segments;
  }

  /// Get an entity at a given path.
  FileSystemEntityMemoryImpl getEntity(String path) {
    // Get the segments list

    return getEntityBySegment(getSegments(path));
  }

  /// Get parent segments.
  List<String> getParentSegments(List<String> segments) {
    return segments.sublist(0, segments.length - 1);
  }

  /// Get by segments.
  FileSystemEntityMemoryImpl getEntityBySegment(List<String> segments) {
    if (segments.first == rootDir.path) {
      return rootDir.getEntity(segments.sublist(1));
    }
    return null;
  }

  /// Create a file.
  FileMemoryImpl createFileBySegments(List<String> segments,
      {bool recursive = false}) {
    FileSystemEntityMemoryImpl fileImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (fileImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      FileSystemEntityMemoryImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent =
              createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is DirectoryMemoryImpl) {
        fileImpl = FileMemoryImpl(parent, segments.last);
        fileImpl.create();
      }
    }
    if (fileImpl is FileMemoryImpl) {
      return fileImpl;
    }
    return null;
  }

  /// Create a directory.
  DirectoryMemoryImpl createDirectoryBySegments(List<String> segments,
      {bool recursive = false}) {
    FileSystemEntityMemoryImpl directoryImpl = getEntityBySegment(segments);
    // if it exists we're fine
    if (directoryImpl == null) {
      // look for parent
      List<String> parentSegments = getParentSegments(segments);
      FileSystemEntityMemoryImpl parent = getEntityBySegment(parentSegments);
      if (parent == null) {
        if (recursive == true) {
          parent =
              createDirectoryBySegments(parentSegments, recursive: recursive);
          // let it continue to create the last segment
        }
      }
      if (parent is DirectoryMemoryImpl) {
        directoryImpl = DirectoryMemoryImpl(parent, segments.last);
        directoryImpl.create();
      }
    }
    if (directoryImpl is DirectoryMemoryImpl) {
      return directoryImpl;
    }
    return null;
  }

  /// open for read.
  Stream<Uint8List> openRead(String path) {
    var ctlr = StreamController<Uint8List>(sync: true);
    FileSystemEntityMemoryImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl is FileMemoryImpl) {
      ctlr.addStream(fileImpl.openRead()).then((_) {
        ctlr.close();
      });
    } else {
      ctlr.addError(FileSystemExceptionMemory(
          path, "Cannot open file", _noSuchPathError));
    }
    return ctlr.stream;
  }

  /// Open for write.
  fs.IOSink openWrite(String path, {fs.FileMode mode = fs.FileMode.write}) {
    _TmpSink sink;
    //StreamController ctlr = new StreamController(sync: true);
    FileSystemEntityMemoryImpl fileImpl = getEntity(path);
    // if it exists we're fine
    if (fileImpl == null) {
      // create if needed
      if (mode == fs.FileMode.write || mode == fs.FileMode.append) {
        fileImpl = createFile(path);
      }
    }
    if (fileImpl is FileMemoryImpl) {
      sink = _TmpSink(path, fileImpl.openWrite(mode));
    } else {
      sink = _TmpSink(path, null);
      //ctlr.addError(new  _MemoryFileSystemException(path, "Cannot open file", _noSuchPathError));
    }
    return sink;
  }

  /// Create a directory.
  DirectoryMemoryImpl createDirectory(String path, {bool recursive = false}) {
    // Go up one by one
    List<String> segments = getSegments(path);
    return createDirectoryBySegments(segments, recursive: recursive);
  }

  /// Create a file.
  FileMemoryImpl createFile(String path, {bool recursive = false}) {
    // Go up one by one
    List<String> segments = getSegments(path);

    return createFileBySegments(segments, recursive: recursive);
  }

  /// true if it exists.
  bool exists(String path) {
    FileSystemEntityMemoryImpl entityImpl = getEntity(path);
    if (entityImpl != null) {
      return true;
    }
    return false;
  }

  /// Delete.
  void delete(String path, {bool recursive = false}) {
    FileSystemEntityMemoryImpl entityImpl = getEntity(path);
    if (entityImpl == null) {
      throw FileSystemExceptionMemory(
          path, "Deletion failed", _noSuchPathError);
    }
    if (entityImpl != null && (!(entityImpl is RootDirectoryMemoryImpl))) {
      if (entityImpl is DirectoryMemoryImpl) {
        if (recursive != true && (entityImpl.children.isNotEmpty)) {
          throw FileSystemExceptionMemory(path, "Deletion failed",
              OSErrorMemory(39, "Directory is not empty"));
        }
      }
      entityImpl.delete();
    }
  }

  /// rename base implementation
  FileSystemEntityMemoryImpl rename(String path, String newPath) {
    FileSystemEntityMemoryImpl entityImpl = getEntity(path);
    if (entityImpl == null) {
      throw FileSystemExceptionMemory(path, "Rename failed", _noSuchPathError);
    }
    if (entityImpl is RootDirectoryMemoryImpl) {
      throw FileSystemExceptionMemory(path, "Rename failed at root");
    }

    List<String> segments = getSegments(newPath);
    // make sure dest does not exist
    FileSystemEntityMemoryImpl newEntityImpl = getEntityBySegment(segments);
    if (newEntityImpl != null) {
      throw FileSystemExceptionMemory(
          path, "Rename failed, destination $newPath exists");
    }
    String segment = segments.last;

    // find dst parent
    FileSystemEntityMemoryImpl newParentImpl =
        getEntityBySegment(getParentSegments(segments));
    if (newParentImpl == null) {
      throw FileSystemExceptionMemory(
          path, "Rename failed, parent destination $newPath does not exist");
    }
    if (newParentImpl is DirectoryMemoryImpl) {
      entityImpl.delete();

      if (entityImpl is FileMemoryImpl) {
        newEntityImpl = FileMemoryImpl(newParentImpl, segment);
        (newEntityImpl as FileMemoryImpl).content = entityImpl.content;
      } else {
        newEntityImpl = DirectoryMemoryImpl(newParentImpl, segment);
      }
      newEntityImpl.create();
      return newEntityImpl;
    } else {
      throw FileSystemExceptionMemory(
          path, "Rename failed, parent destination $newPath not a directory");
    }
  }

  /// Root directory.
  RootDirectoryMemoryImpl rootDir = RootDirectoryMemoryImpl();

  /// File type.
  Future<fs.FileSystemEntityType> type(String path, {bool followLinks = true}) {
    return Future.sync(() {
      FileSystemEntityMemoryImpl impl = getEntity(path);
      if (impl != null) {
        return impl.type;
      }
      return fs.FileSystemEntityType.notFound;
    });
  }

  @override
  String toString() => "memory";
}
