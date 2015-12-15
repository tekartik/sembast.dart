library sembast.fs;

import 'dart:async';
import 'dart:convert';
import '../sembast.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';
import 'file_system.dart';

class _FsDatabaseStorage extends DatabaseStorage {
  final FileSystem fs;
  final File file;
  bool isTmp;

  Logger log = new Logger("FsDatabaseStorage");

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
      return file.delete(recursive: true).catchError((_) {});
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
        // try to recover from tmp file
        return new Future.sync(() {
          if (isTmp == true) {
            return false;
          } else {
            return tmpRecover();
          }
        }).then((bool done) {
          if (!done) {
            return file.create(recursive: true).then((File file) {})
                .catchError((e) {
              return fs.isFile(path).then((isFile) {
                if (!isFile) {
                  throw e;
                }
              });
            });
          } else {
            // ok found fine
          }
        });
      }
    });
  }

  String get tmpPath => join(dirname(path), "~${basename(path)}");

  @override
  DatabaseStorage get tmpStorage {
    return new _FsDatabaseStorage(fs, tmpPath)..isTmp = true;
  }

  @override
  Future<bool> tmpRecover() {
    return new Future.sync(() {
      return fs.isFile(tmpPath).then((bool isFile) {
        log.info("Recovering from ${tmpPath}");

        if (isFile) {
          return file.delete().catchError((e) {
            print('fail to delete');
            print(e);
            return true;
          }).whenComplete(() {
            return fs
                .newFile(tmpPath)
                .rename(file.path)
                .then((File renamedFile) {
              // ok
              return true;
            });
          });
        }
        return false;
      });
    });
  }

  Stream<String> readLines() {
    return file
        .openRead()
        .transform(UTF8.decoder as StreamTransformer<List<int>, String>)
        .transform(new LineSplitter()) as Stream<String>;
  }

  Future appendLines(List<String> lines) {
    IOSink sink = file.openWrite(mode: FileMode.APPEND);

    lines.forEach((String line) {
      sink.writeln(line);
    });

    return sink.close();
  }

  @override
  String toString() {
    Map map = {"file": file.toString(), "fs": fs.toString()};
    if (isTmp == true) {
      map['tmp'] = true;
    }
    return map.toString();
  }
}

/// FileSystem implementation
class FsDatabaseFactory implements DatabaseFactory {
  final FileSystem fs;
  FsDatabaseFactory(this.fs);

  @override
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    Database db = new Database(new _FsDatabaseStorage(fs, path));
    return db.open(
        version: version, onVersionChanged: onVersionChanged, mode: mode);
  }

  @override
  Future deleteDatabase(String path) {
    return new _FsDatabaseStorage(fs, path).delete();
  }

  @override
  bool get hasStorage => true;
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
