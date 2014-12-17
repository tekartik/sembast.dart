library sembast.io;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'sembast.dart';

class _IoDatabaseStorage extends DatabaseStorage {
  final File file;

  _IoDatabaseStorage(String path) : file = new File(path);

  @override
  bool get supported => true;

  @override
  String get path => file.path;

  @override
  Future delete() {
    return new File(path).exists().then((exists) {
      return new File(path).delete(recursive: true).catchError((_) {
      });
    });
  }

  @override
  Future<bool> find() {
    return FileSystemEntity.isFile(path);
  }
  
  @override
  Future findOrCreate() {
    return FileSystemEntity.isFile(path).then((isFile) {
      if (!isFile) {
        return file.create(recursive: true).then((File file) {

        }).catchError((e) {
          return FileSystemEntity.isFile(path).then((isFile) {
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
/// In memory implementation
class IoDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    Database db = new Database(new _IoDatabaseStorage(path));
    return db.open(version: version, onVersionChanged: onVersionChanged, mode: mode);

  }

  @override
  Future deleteDatabase(String path) {
    return new _IoDatabaseStorage(path).delete();
  }

  bool get persistent => true;

//  Stream<String> getData(String path) {
//    File file = new File(path);
//
//          _mainStore = new Store._(this, _main_store);
//          _stores[_main_store] = _mainStore;
//
//          bool needCompact = false;
//          return file.openRead().transform(UTF8.decoder).transform(new LineSplitter())
//  }
}

final IoDatabaseFactory ioDatabaseFactory = new IoDatabaseFactory();
///
/// Open a new of existing database
///
/// [path] is the location of the database
/// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called
/// if [failIfNotFound] is true, open will return a null database if not found
/// if [empty] is true, the existing database
Future<Database> openIoDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode: DatabaseMode.CREATE}) {
  return ioDatabaseFactory.openDatabase(path, version: version, onVersionChanged: onVersionChanged, mode: mode);
}
