library sembast.test.test_common;

// basically same as the io runner but with extra output
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/sembast.dart';
import 'dart:async';
import 'package:sembast/src/file_system.dart';
import 'package:dev_test/test.dart';
export 'package:dev_test/test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:path/path.dart';
import 'dart:convert';

// For test in memory
DatabaseTestContext get memoryDatabaseContext =>
    DatabaseTestContext()..factory = memoryDatabaseFactory;
FsDatabaseTestContext get memoryFsDatabaseContext =>
    FsDatabaseTestContext()..factory = memoryFsDatabaseFactory;

class FsDatabaseTestContext extends DatabaseTestContext {
  FileSystem get fs => (factory as FsDatabaseFactory).fs;
  @override
  String get dbPath => join(fs.currentDirectory.path, super.dbPath);
}

class DatabaseTestContext {
  DatabaseFactory factory;

  String get dbPath => joinAll(testDescriptions) + ".db";

  // Delete the existing and open the database
  Future<Database> open([int version]) async {
    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}

// FileSystem context
class FileSystemTestContext {
  FileSystem fs;
  String get outPath => fs.currentDirectory.path;
}

FileSystemTestContext get memoryFileSystemContext =>
    FileSystemTestContext()..fs = memoryFileSystem;

Future<Database> setupForTest(DatabaseTestContext ctx) => ctx.open();

Future<List<Record>> recordStreamToList(Stream<Record> stream) {
  List<Record> records = [];
  return stream
      .listen((Record record) {
        records.add(record);
      })
      .asFuture()
      .then((_) => records);
}

///
/// helper to read a list of string (lines)
///
Future<List<String>> readContent(FileSystem fs, String filePath) {
  List<String> content = [];
  return fs
      .newFile(filePath)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
}

Future writeContent(FileSystem fs, String filePath, List<String> lines) async {
  File file = fs.newFile(filePath);
  await file.create(recursive: true);
  IOSink sink = file.openWrite(mode: FileMode.write);
  for (String line in lines) {
    sink.writeln(line);
  }
  await sink.close();
}

void devPrintJson(Map json) {
  print(const JsonEncoder.withIndent("  ").convert(json));
}

Future<Database> reOpen(Database db, {DatabaseMode mode}) {
  return (db as SembastDatabase).reOpen(mode: mode);
}
