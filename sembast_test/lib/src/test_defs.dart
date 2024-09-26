library;

import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';

// ignore_for_file: implementation_imports
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/memory/file_system_memory.dart';

import '../test_common.dart';
import 'import_database.dart';

export 'package:sembast/src/env_utils.dart'
    show isRunningAsJavascript, kSembastDartIsWeb;

DatabaseTestContext get memoryDatabaseContext =>
    DatabaseTestContext()..factory = databaseFactoryMemory;

class TestException implements Exception {
  @override
  String toString() => 'TestException';
}

// FileSystem context
class FileSystemTestContext {
  FileSystem? fs;

//String get outPath => fs.currentDirectory.path;
}

FileSystemTestContext get memoryFileSystemContext =>
    FileSystemTestContext()..fs = fileSystemMemory;

String dbPathFromName(String name) =>
    join('.dart_tool', 'sembast', 'test', name);

Future<Database> setupForTest(DatabaseTestContext ctx, String name,
    {SembastCodec? codec}) {
  return ctx.deleteAndOpen(dbPathFromName(name), codec: codec);
}

/// Delete the database and returns its full path.
Future<String> deleteForTest(DatabaseTestContext ctx, String name) async {
  var dbPath = dbPathFromName(name);
  await ctx.factory.deleteDatabase(dbPath);
  return dbPath;
}

///
/// helper to read a list of string (lines)
///
Future<List<String>> readContent(FileSystem fs, String filePath) {
  final content = <String>[];
  return utf8.decoder
      .bind(fs.file(filePath).openRead())
      .transform(const LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
}

Future writeContent(FileSystem fs, String filePath, List<String> lines) async {
  final file = fs.file(filePath);
  await file.create(recursive: true);
  final sink = file.openWrite(mode: FileMode.write);
  for (var line in lines) {
    sink.writeln(line);
  }
  await sink.close();
}

void devPrintJson(Map json) {
  print(const JsonEncoder.withIndent('  ').convert(json));
}

Future<Database> reOpen(Database db, {DatabaseMode? mode}) {
  return (db as SembastDatabase)
      .reOpen(DatabaseOpenOptions(mode: mode, codec: db.sembastCodec));
}

bool hasStorage(DatabaseFactory factory) =>
    // ignore: deprecated_member_use_from_same_package
    (factory as SembastDatabaseFactory).hasStorage;

bool hasStorageJdb(DatabaseFactory? factory) => factory is DatabaseFactoryJdb;

/// Get an existing database version
Future<int> getExistingDatabaseVersion(
    DatabaseFactory factory, String path) async {
  var db = await factory.openDatabase(path, mode: DatabaseMode.existing);
  final version = db.version;
  await db.close();
  return version;
}

/// True on the vm (not node.js)
bool get isJavascriptVm => isRunningAsJavascript;
