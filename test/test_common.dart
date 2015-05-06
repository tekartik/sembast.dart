library sembast.database_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/file_system.dart';
import 'package:path/path.dart';
import 'dart:convert';

Future<Database> setupForTest(DatabaseFactory factory, String path) {
  return factory.deleteDatabase(path).then((_) {
    return factory.openDatabase(path);
  });
}

String testOutDbPath(FileSystem fs) {
  return join(testOutPath(fs), "test.db");

}
String testOutPath(FileSystem fs) {

  //String DATA_FOLDER = 'data';
  //String OUT_FOLDER = 'out';

  String _rootPath() {
    if (fs.scriptFile != null) {
      return dirname(fs.scriptFile.path);
    }
    return fs.currentDirectory.path;
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
  return fs.newFile(filePath).openRead().transform(UTF8.decoder).transform(new LineSplitter()).listen((String line) {
    content.add(line);
  }).asFuture(content);
}
