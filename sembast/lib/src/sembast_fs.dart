library sembast.fs;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/log_level.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/storage.dart';

import 'common_import.dart';
import 'file_system.dart';

/// File system storage.
class FsDatabaseStorage extends DatabaseStorage {
  /// File system
  final FileSystem fs;

  /// File
  final File file;

  /// Whether it is a temp file
  bool isTmp;

  /// log level
  final bool logV = databaseStorageLogLevel == SembastLogLevel.verbose;

  /// File system storage constructor.
  FsDatabaseStorage(this.fs, String path) : file = fs.file(path);

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

  /// Temp path
  String get tmpPath => join(dirname(path), '~${basename(path)}');

  @override
  DatabaseStorage get tmpStorage {
    return FsDatabaseStorage(fs, tmpPath)..isTmp = true;
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
  Stream<String> readSafeLines() {
    StreamSubscription subscription;
    Uint8List currentLine;
    const endOfLine = 10;
    const lineFeed = 13;
    StreamController<String> ctlr;
    ctlr = StreamController<String>(onListen: () {
      void addCurrentLine() {
        if (currentLine?.isNotEmpty ?? false) {
          try {
            ctlr.add(utf8.decode(currentLine));
          } catch (_) {
            // Ignore non utf8 lines
          }
        }
        currentLine = null;
      }

      void addToCurrentLine(Uint8List data) {
        if (currentLine == null) {
          currentLine = data;
        } else {
          var newCurrentLine = Uint8List(currentLine.length + data.length);
          newCurrentLine.setAll(0, currentLine);
          newCurrentLine.setAll(currentLine.length, data);
          currentLine = newCurrentLine;
        }
      }

      subscription = file.openRead().listen((data) {
        // devPrint('read $data');
        // look for \n (10)
        var start = 0;
        for (var i = 0; i < data.length; i++) {
          var byte = data[i];
          if (byte == endOfLine || byte == lineFeed) {
            addToCurrentLine(data.sublist(start, i));
            addCurrentLine();
            // Skip it
            start = i + 1;
          }
        }
        // Store last current line
        if (data.length > start) {
          addToCurrentLine(data.sublist(start, data.length));
        }
      }, onDone: () {
        // Last one
        if (currentLine != null) {
          addCurrentLine();
        }
        ctlr.close();
      });
    }, onCancel: () {
      subscription?.cancel();
    });

    return ctlr.stream;
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
      SembastDatabase(openHelper, FsDatabaseStorage(fs, openHelper.path));

  @override
  Future doDeleteDatabase(String path) async {
    return FsDatabaseStorage(fs, path).delete();
  }

  @override
  bool get hasStorage => true;
}
