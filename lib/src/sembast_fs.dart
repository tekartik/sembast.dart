library sembast.fs;

import 'dart:async';
import 'dart:convert';
import '../sembast.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';
import 'file_system.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/storage.dart';

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
  Future delete() async {
    if (await file.exists()) {
      try {
        await file.delete(recursive: true);
      } catch (_) {}
    }
  }

  @override
  Future<bool> find() {
    return fs.isFile(path);
  }

  @override
  Future findOrCreate() async {
    if (!(await fs.isFile(path))) {
      bool done;
      // try to recover from tmp file
      if (isTmp == true) {
        done = false;
      } else {
        done = await tmpRecover();
      }

      if (!done) {
        try {
          await file.create(recursive: true);
        } catch (e) {
          if (!(await fs.isFile(path))) {
            rethrow;
          }
        }
      } else {
        // ok found fine
      }
    }
  }

  String get tmpPath => join(dirname(path), "~${basename(path)}");

  @override
  DatabaseStorage get tmpStorage {
    return new _FsDatabaseStorage(fs, tmpPath)..isTmp = true;
  }

  @override
  Future<bool> tmpRecover() async {
    bool isFile = await fs.isFile(tmpPath);
    log.info("Recovering from ${tmpPath}");

    if (isFile) {
      try {
        await file.delete();
      } catch (e) {
        log.warning('fail to delete $e');
        //return true;
      }
      await fs.newFile(tmpPath).rename(file.path);

      // ok
      return true;
    } else {
      return false;
    }
  }

  Stream<String> readLines() {
    return file
        .openRead()
        .transform(UTF8.decoder)
        .transform(new LineSplitter());
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
    SembastDatabase db = new SembastDatabase(new _FsDatabaseStorage(fs, path));
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
