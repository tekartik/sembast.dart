library sembast.test.src.test_defs;

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/api/v2/sembast_memory.dart';

import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/memory/file_system_memory.dart';

import '../test_common.dart';

DatabaseTestContext get memoryDatabaseContext =>
    DatabaseTestContext()..factory = databaseFactoryMemory;

class TestException implements Exception {
  @override
  String toString() => 'TestException';
}

// FileSystem context
class FileSystemTestContext {
  FileSystem fs;

  //String get outPath => fs.currentDirectory.path;
}

FileSystemTestContext get memoryFileSystemContext =>
    FileSystemTestContext()..fs = memoryFileSystem;

String dbPathFromName(String name) =>
    join('.dart_tool', 'sembast', 'test', name);

Future<Database> setupForTest(DatabaseTestContext ctx, String name) {
  return ctx.open(dbPathFromName(name));
}

///
/// helper to read a list of string (lines)
///
Future<List<String>> readContent(FileSystem fs, String filePath) {
  List<String> content = [];
  return utf8.decoder
      .bind(fs.file(filePath).openRead())
      .transform(const LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
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

bool hasStorage(DatabaseFactory factory) =>
    // ignore: deprecated_member_use_from_same_package
    (factory as SembastDatabaseFactory).hasStorage;

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
