library;

import 'dart:async';
import 'dart:convert';

import 'dart:typed_data';

/// The modes in which a File can be opened.
class FileMode {
  /// The mode for opening a file only for reading.
  static const read = FileMode._internal(0);

  /// The mode for opening a file for reading and writing. The file is
  /// overwritten if it already exists. The file is created if it does not
  /// already exist.
  static const write = FileMode._internal(1);

  /// The mode for opening a file for reading and writing to the
  /// end of it. The file is created if it does not already exist.
  static const append = FileMode._internal(2);

  final int _mode;

  /// internal mode.
  int get mode => _mode;

  const FileMode._internal(this._mode);
}

/// OS Error.
abstract class OSError {
  /// Constant used to indicate that no OS error code is available.
  static const int noErrorCode = -1;

  /// Error code supplied by the operating system. Will have the value
  /// [noErrorCode] if there is no error code associated with the error.
  int get errorCode;

  /// Error message supplied by the operating system. null if no message is
  /// associated with the error.
  String get message;
}

/// File system exception.
abstract class FileSystemException {
  /// Message describing the error. This does not include any detailed
  /// information form the underlying OS error. Check [osError] for
  /// that information.
  String get message;

  ///
  /// The file system path on which the error occurred. Can be `null`
  /// if the exception does not relate directly to a file system path.
  ///
  String? get path;

  /// The underlying OS error. Can be `null` if the exception is not
  /// raised due to an OS error.
  OSError? get osError;
}

/// File system.
abstract class FileSystem {
  /// Creates a [Directory] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [Directory.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  Directory directory(String path);

  /// Creates a [File] object.
  ///
  /// If [path] is a relative path, it will be interpreted relative to the
  /// current working directory (see [Directory.current]), when used.
  ///
  /// If [path] is an absolute path, it will be immune to changes to the
  /// current working directory.
  File file(String path);

  /// Finds the type of file system object that a path points to. Returns
  /// a [`Future<FileSystemEntityType>`] that completes with the result.
  ///
  /// [FileSystemEntityType] has the constant instances FILE, DIRECTORY,
  /// LINK, and NOT_FOUND.  [type] will return LINK only if the optional
  /// named argument [followLinks] is false, and [path] points to a link.
  /// If the path does not point to a file system object, or any other error
  /// occurs in looking up the path, NOT_FOUND is returned.  The only
  /// error or exception that may be put on the returned future is ArgumentError,
  /// caused by passing the wrong type of arguments to the function.
  Future<FileSystemEntityType> type(String path, {bool followLinks = true});

  /// Checks if type(path) returns FileSystemEntityType.FILE.
  Future<bool> isFile(String path);

  /// Checks if type(path) returns FileSystemEntityType.DIRECTORY.
  Future<bool> isDirectory(String path);

  ///
  /// Current directory if any
  ///
  Directory get currentDirectory;

  ///
  /// Current running script file if any
  ///
  File? get scriptFile;
}

/// IO sink.
abstract class IOSink {
  /// Converts [obj] to a String by invoking [Object.toString] and
  /// writes the result to `this`, followed by a newline.
  ///
  /// This operation is non-blocking. See [flush] or [done] for how to get any
  /// errors generated by this call.
  void writeln([Object obj = '']);

  /// Close the target consumer.
  Future<void> close();
}

/// The type of an entity on the file system, such as a file, directory, or link.
///
/// These constants are used by the [FileSystemEntity] class
/// to indicate the object's type.
///
class FileSystemEntityType {
  /// File type.
  static const file = FileSystemEntityType._internal(0);

  /// Directory type.
  static const directory = FileSystemEntityType._internal(1);

  /// Link type.
  static const link = FileSystemEntityType._internal(2);

  /// Not found.
  static const notFound = FileSystemEntityType._internal(3);

  final int _type;

  const FileSystemEntityType._internal(this._type);

  //static FileSystemEntityType _lookup(int type) => _typeList[type];
  @override
  String toString() => const ['FILE', 'DIRECTORY', 'LINK', 'NOT_FOUND'][_type];
}

/// File system entity.
abstract class FileSystemEntity {
  /// Checks whether the file system entity with this path exists. Returns
  /// a [`Future<bool>`] that completes with the result.
  ///
  /// Since FileSystemEntity is abstract, every FileSystemEntity object
  /// is actually an instance of one of the subclasses [File],
  /// [Directory], and [Link].  Calling [exists] on an instance of one
  /// of these subclasses checks whether the object exists in the file
  /// system object exists and is of the correct type (file, directory,
  /// or link).  To check whether a path points to an object on the
  /// file system, regardless of the object's type, use the [type]
  /// static method.
  ///
  Future<bool> exists();

  /// Get the path of the file.
  String get path;

  /// Deletes this [FileSystemEntity].
  ///
  /// If the [FileSystemEntity] is a directory, and if [recursive] is false,
  /// the directory must be empty. Otherwise, if [recursive] is true, the
  /// directory and all sub-directories and files in the directories are
  /// deleted. Links are not followed when deleting recursively. Only the link
  /// is deleted, not its target.
  ///
  /// If [recursive] is true, the [FileSystemEntity] is deleted even if the type
  /// of the [FileSystemEntity] doesn't match the content of the file system.
  /// This behavior allows [delete] to be used to unconditionally delete any file
  /// system object.
  ///
  /// Returns a [`Future<FileSystemEntity>`] that completes with this
  /// [FileSystemEntity] when the deletion is done. If the [FileSystemEntity]
  /// cannot be deleted, the future completes with an exception.
  Future<FileSystemEntity> delete({bool recursive = false});

  /// Renames this file system entity. Returns a `Future<FileSystemEntity>`
  /// that completes with a [FileSystemEntity] instance for the renamed
  /// file system entity.
  ///
  /// If [newPath] identifies an existing entity of the same type, that entity
  /// is replaced. If [newPath] identifies an existing entity of a different
  /// type, the operation fails and the future completes with an exception.
  Future<FileSystemEntity> rename(String newPath);

  /// Get the [FileSystem] from a file system entity
  FileSystem get fileSystem;
}

/// Directory.
abstract class Directory extends FileSystemEntity {
  /// Creates the directory with this name.
  ///
  /// If [recursive] is false, only the last directory in the path is
  /// created. If [recursive] is true, all non-existing path components
  /// are created. If the directory already exists nothing is done.
  ///
  /// Returns a [`Future<Directory>`] that completes with this
  /// directory once it has been created. If the directory cannot be
  /// created the future completes with an exception.
  Future<Directory> create({bool recursive = false});
}

/// File.
abstract class File extends FileSystemEntity {
  /// Create the file. Returns a [`Future<File>`] that completes with
  /// the file when it has been created.
  ///
  /// If [recursive] is false, the default, the file is created only if
  /// all directories in the path exist. If [recursive] is true, all
  /// non-existing path components are created.
  ///
  /// Existing files are left untouched by [create]. Calling [create] on an
  /// existing file might fail if there are restrictive permissions on
  /// the file.
  ///
  /// Completes the future with a [FileSystemException] if the operation fails.
  Future<File> create({bool recursive = false});

  /// Create a new independent [Stream] for the contents of this file.
  ///
  /// If [start] is present, the file will be read from byte-offset [start].
  /// Otherwise from the beginning (index 0).
  ///
  /// If [end] is present, only up to byte-index [end] will be read. Otherwise,
  /// until end of file.
  ///
  /// In order to make sure that system resources are freed, the stream
  /// must be read to completion or the subscription on the stream must
  /// be cancelled.
  Stream<Uint8List> openRead([int? start, int? end]);

  /// Creates a new independent [IOSink] for the file. The
  /// [IOSink] must be closed when no longer used, to free
  /// system resources.
  ///
  /// An [IOSink] for a file can be opened in two modes:
  ///
  /// * [FileMode.WRITE]: truncates the file to length zero.
  /// * [FileMode.APPEND]: sets the initial write position to the end
  ///   of the file.
  ///
  ///  When writing strings through the returned [IOSink] the encoding
  ///  specified using [encoding] will be used. The returned [IOSink]
  ///  has an [:encoding:] property which can be changed after the
  ///  [IOSink] has been created.
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8});

  /// Renames this file. Returns a `Future<File>` that completes
  /// with a [File] instance for the renamed file.
  ///
  /// If [newPath] identifies an existing file, that file is
  /// replaced. If [newPath] identifies an existing directory, the
  /// operation fails and the future completes with an exception.
  @override
  Future<File> rename(String newPath);
}
