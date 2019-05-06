library sembast.test.test_common;

// basically same as the io runner but with extra output
import 'dart:async';
import 'dart:convert';

import 'package:dev_test/test.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/memory/file_system_memory.dart';
import 'package:sembast/src/sembast_fs.dart';

export 'package:dev_test/test.dart';

class TestException implements Exception {
  @override
  String toString() => 'TestException';
}

// For test in memory
DatabaseTestContext get memoryDatabaseContext =>
    DatabaseTestContext()..factory = databaseFactoryMemory;

DatabaseTestContextFs get memoryFsDatabaseContext =>
    DatabaseTestContextFs()..factory = databaseFactoryMemoryFs;

class DatabaseTestContextFs extends DatabaseTestContext {
  FileSystem get fs => (factory as DatabaseFactoryFs).fs;

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
      .file(filePath)
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
}

List getRecordsValues(List<Record> records) {
  var list = [];
  for (var record in records) {
    list.add(record.value);
  }
  return list;
}

Future writeContent(FileSystem fs, String filePath, List<String> lines) async {
  File file = fs.file(filePath);
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
  return (db as SembastDatabase).reOpen(DatabaseOpenOptions(mode: mode));
}

/// Get an existing database version
Future<int> getExistingDatabaseVersion(
    DatabaseFactory factory, String path) async {
  var db = await factory.openDatabase(path, mode: DatabaseMode.existing);
  int version = db.version;
  await db.close();
  return version;
}

/// True on the browser
bool get isJavascriptVm => identical(1.0, 1);
