library tekartik_iodb.database_io;

import 'dart:io';
import 'dart:async';

import 'database.dart';

/// In memory implementation
class IoDatabaseFactory implements DatabaseFactory {
  @override
  Future<Database> openDatabase(String path, {int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    Database db = new Database(this, path);
    return db.open(path, version);

  }

  @override
  Future deleteDatabase(String path) {
    return new File(path).exists().then((exists) {
      return new File(path).delete(recursive: true).catchError((_) {
      });
    });
  }
  
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

class _IoDatabase extends Database {
}
