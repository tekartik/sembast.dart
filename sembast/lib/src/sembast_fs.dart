library sembast.fs;

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/storage.dart';

import 'file_system.dart';

class _FsDatabaseStorage extends DatabaseStorage {
  final FileSystem fs;
  final File file;
  bool isTmp;
  final bool logV = databaseStorageLogLevel == SembastLogLevel.verbose;

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

  String get tmpPath => join(dirname(path), '~${basename(path)}');

  @override
  DatabaseStorage get tmpStorage {
    return _FsDatabaseStorage(fs, tmpPath)..isTmp = true;
  }

  @override
  Future<bool> tmpRecover() async {
    final isFile = await fs.isFile(tmpPath);
    if (logV) {
      print('Recovering from ${tmpPath}');
    }

    if (isFile) {
      try {
        await file.delete();
      } catch (e) {
        if (logV) {
          print('fail to delete $e');
        }
        //return true;
      }
      // devPrint('renaming $tmpPath to ${file.path}');
      await fs.file(tmpPath).rename(file.path);

      // ok
      return true;
    } else {
      return false;
    }
  }

  @override
  Stream<String> readLines() {
    return utf8.decoder.bind(file.openRead()).transform(const LineSplitter());
  }

  @override
  Future appendLines(List<String> lines) {
    // devPrint('${file.path} lines $lines');
    final sink = file.openWrite(mode: FileMode.append);

    lines.forEach((String line) {
      sink.writeln(line);
    });

    return sink.close();
  }

  @override
  String toString() {
    final map = <String, dynamic>{'file': file.toString(), 'fs': fs.toString()};
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
  /// File system used.
  final FileSystem fs;

  /// Constructor.
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
