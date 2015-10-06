library sembast.database_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/file_system.dart';
import 'package:dev_test/test.dart';
export 'package:dev_test/test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'dart:math';

// For test in memory
DatabaseTestContext get memoryDatabaseContext => new DatabaseTestContext()..factory = memoryDatabaseFactory;
FsDatabaseTestContext get memoryFsDatabaseContext => new FsDatabaseTestContext()..factory = new FsDatabaseFactory(memoryFileSystem);

class FsDatabaseTestContext extends DatabaseTestContext {

}

class DatabaseTestContext {
  DatabaseFactory factory;

  String get dbPath => joinAll(testDescriptions) + ".db";

}

// FileSystem context
class FileSystemTestContext {
  FileSystem fs;
  String get outPath => fs.currentDirectory.path;
}

FileSystemTestContext get memoryFileSystemTestContext => new FileSystemTestContext()..fs = memoryFileSystem;

String getTestDbPath(String topPath) {
  String sub = joinAll(testDescriptions) + ".db";
  if (topPath == null) {
    return sub;
  }
  return join(topPath, sub);
}

Future<Database> setupForTest(DatabaseTestContext ctx) async {
  DatabaseFactory factory = ctx.factory;
  String dbPath = ctx.dbPath;
  await factory.deleteDatabase(dbPath);
  return factory.openDatabase(dbPath);
}

Future<Database> setupDbPathForTest(DatabaseFactory factory, String topPath) {

}
/*
Future<Database> setupForTest(DatabaseFactory factory, [String path]) {
  if (path == null) {
    path = testOutFactoryDbPath(factory);
  }
  return factory.deleteDatabase(path).then((_) {
    return factory.openDatabase(path);
  });
}
*/

/*
String testOutFactoryDbPath(DatabaseFactory factory) {
  if (factory is FsDatabaseFactory) {
    FileSystem fs = factory.fs;
    return testOutDbPath(fs);
  } else {
    return "test.db";
  }
}
*/

/*
String testOutDbPath(FileSystem fs) {
  return join(testOutPath(fs), "test.db");
}
*/

/*
String testOutPath(FileSystem fs) {
  //String DATA_FOLDER = 'data';
  //String OUT_FOLDER = 'out';
  bool _isIo = fs.toString() == "io";
  String _rootPath() {
    if (_isIo) {
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

  if (_isIo) {
    // to allow multiple tests
    int rand = new Random(new DateTime.now().millisecondsSinceEpoch)
        .nextInt(1 << 32 - 1);
    return join(_rootPath(), "tmp", rand.toString());
  } else {
    return join(_rootPath(), "tmp");
  }
}
*/

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

Future writeContent(FileSystem fs, String filePath, List<String> lines) async {
  File file = fs.newFile(filePath);
  await file.create(recursive: true);
  IOSink sink = file.openWrite(mode: FileMode.WRITE);
  for (String line in lines) {
    sink.writeln(line);
  }
  await sink.close();
}

DatabaseExportStat getDatabaseExportStat(Database db) {
  return new DatabaseExportStat.fromJson(db.toJson()["exportStat"]);
}

devPrintJson(Map json) {
  print(const JsonEncoder.withIndent("  ").convert(json));
}
