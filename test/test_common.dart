library sembast.database_test;

import 'dart:mirrors';
// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:path/path.dart';
import 'dart:convert';

// just for mirror
class _TestUtils {}

Future<Database> setupForTest(DatabaseFactory factory, [String path]) {
  if (path == null) {
    path = testOutFactoryDbPath(factory);
  }
  return factory.deleteDatabase(path).then((_) {
    return factory.openDatabase(path);
  });
}

String testOutFactoryDbPath(DatabaseFactory factory) {
  if (factory is FsDatabaseFactory) {
    FileSystem fs = factory.fs;
    return testOutDbPath(fs);
  } else {
    return "test.db";
  }
}

String testOutDbPath(FileSystem fs) {
  return join(testOutPath(fs), "test.db");
}

String testOutPath(FileSystem fs) {
  //String DATA_FOLDER = 'data';
  //String OUT_FOLDER = 'out';
  String _rootPath() {
    if (fs.toString() == "io") {
      final String _testScriptPath =
          (reflectClass(_TestUtils).owner as LibraryMirror).uri.toFilePath();
      return dirname(_testScriptPath);
    } else {
      if (fs.scriptFile != null) {
        return dirname(fs.scriptFile.path);
      }
      return fs.currentDirectory.path;
    }
  }

  //String dataPath = join(_rootPath(), DATA_FOLDER);
  //String outDataPath = join(dataPath, OUT_FOLDER);
  return join(_rootPath(), "tmp");
}

Future<List<Record>> recordStreamToList(Stream<Record> stream) {
  List<Record> records = [];
  return stream.listen((Record record) {
    records.add(record);
  }).asFuture().then((_) => records);
}

///
/// helper to read a list of string (lines)
///
Future<List<String>> readContent(FileSystem fs, String filePath) {
  List<String> content = [];
  return fs
      .newFile(filePath)
      .openRead()
      .transform(UTF8.decoder)
      .transform(new LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
}
