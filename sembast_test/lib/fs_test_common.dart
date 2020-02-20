import 'dart:convert';

import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';

class DatabaseTestContextFs extends DatabaseTestContext {
  FileSystem get fs => (factory as DatabaseFactoryFs).fs;
}

DatabaseTestContextFs get memoryFsDatabaseContext =>
    DatabaseTestContextFs()..factory = databaseFactoryMemoryFs;

///
/// helper to read a list of string (lines)
///
Future<List<Map<String, dynamic>>> fsExportToMapList(
        FileSystem fs, String filePath) async =>
    (await fsExportToStringList(fs, filePath))
        .map((line) => (jsonDecode(line) as Map)?.cast<String, dynamic>())
        .toList(growable: false);

///
/// helper to read a list of string (lines)
///
Future fsImportFromMapList(
    FileSystem fs, String filePath, List<Map<String, dynamic>> mapList) async {
  var sink = fs.file(filePath).openWrite();
  for (var map in mapList) {
    sink.writeln(jsonEncode(map));
  }
  await sink.close();
}

///
/// helper to read a list of string (lines)
///
Future<List<String>> fsExportToStringList(FileSystem fs, String filePath) {
  final content = <String>[];
  return utf8.decoder
      .bind(fs.file(filePath).openRead())
      .transform(const LineSplitter())
      .listen((String line) {
    content.add(line);
  }).asFuture(content);
}
