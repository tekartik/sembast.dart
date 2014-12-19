library sembast.fs;

import 'dart:async';
import 'dart:convert';
import '../sembast.dart';

import 'file_system.dart';

class _FsDatabaseStorage extends DatabaseStorage {
  final FileSystem fs;
  final File file;

  _FsDatabaseStorage(FileSystem fs, String path)
      : fs = fs,
        file = fs.newFile(path);

  @override
  bool get supported => true;

  @override
  String get path => file.path;

  @override
  Future delete() {
    return file.exists().then((exists) {
      return file.delete(recursive: true).catchError((_) {
      });
    });
  }

  @override
  Future<bool> find() {
    return fs.isFile(path);
  }

  @override
  Future findOrCreate() {
    return fs.isFile(path).then((isFile) {
      if (!isFile) {
        return file.create(recursive: true).then((File file) {

        }).catchError((e) {
          return fs.isFile(path).then((isFile) {
            if (!isFile) {
              throw e;
            }
          });
        });
      }
    });
  }

  Stream<String> readLines() {
    return file.openRead().transform(UTF8.decoder).transform(new LineSplitter());
  }

  Future appendLines(List<String> lines) {
    IOSink sink = file.openWrite(mode: FileMode.APPEND);

    lines.forEach((String line) {
      sink.writeln(line);
    });

    return sink.close();
  }

}
/// FileSystem implementation
class FsDatabaseFactory implements DatabaseFactory {
  final FileSystem fs;
  FsDatabaseFactory(this.fs);

  @override
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    Database db = new Database(new _FsDatabaseStorage(fs, path));
    return db.open(version: version, onVersionChanged: onVersionChanged, mode: mode);

  }

  @override
  Future deleteDatabase(String path) {
    return new _FsDatabaseStorage(fs, path).delete();
  }

  bool get persistent => true;
}

//final FsDatabaseFactory ioDatabaseFactory = new FsDatabaseFactory();
///
/// Open a new of existing database
///
/// [path] is the location of the database
/// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called
/// if [failIfNotFound] is true, open will return a null database if not found
/// if [empty] is true, the existing database
//Future<Database> openIoDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode: DatabaseMode.CREATE}) {
//  return ioDatabaseFactory.openDatabase(path, version: version, onVersionChanged: onVersionChanged, mode: mode);
//}
