library sembast.fs;

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/storage.dart';

import 'file_system.dart';

class _FsDatabaseStorage extends DatabaseStorage {
  final FileSystem fs;
  final File file;
  bool isTmp;

  Logger log = Logger("FsDatabaseStorage");

  _FsDatabaseStorage(this.fs, String path) : file = fs.file(path);

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
    return _FsDatabaseStorage(fs, tmpPath)..isTmp = true;
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
      await fs.file(tmpPath).rename(file.path);

      // ok
      return true;
    } else {
      return false;
    }
  }

  @override
  Stream<String> readLines() {
    return file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  @override
  Future appendLines(List<String> lines) {
    IOSink sink = file.openWrite(mode: FileMode.append);

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
class DatabaseFactoryFs extends SembastDatabaseFactory
    with DatabaseFactoryMixin
    implements DatabaseFactory {
  final FileSystem fs;

  DatabaseFactoryFs(this.fs);

  @override
  SembastDatabase newDatabase(DatabaseOpenHelper openHelper) =>
      SembastDatabase(openHelper, _FsDatabaseStorage(fs, openHelper.path));

  @override
  Future doDeleteDatabase(String path) async {
    return _FsDatabaseStorage(fs, path).delete();
  }

  @override
  bool get hasStorage => true;
}
