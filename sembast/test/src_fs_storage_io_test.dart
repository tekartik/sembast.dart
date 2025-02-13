@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:test/test.dart';

import 'io_test_common.dart';

void main() {
  final fs = fileSystemContextIo.fs;
  group('fs_storage_io', () {
    test('corrupted', () async {
      var path = join('.dart_tool', 'sembast', 'test', 'corrupted_non_utf8.db');
      var storage = FsDatabaseStorage(fs, path);
      await storage.delete();
      await storage.findOrCreate();
      await io.File(path).writeAsBytes([195, 9], flush: true);

      try {
        await storage.readLines().first;
        fail('should fail');
      } on FormatException catch (_) {}

      expect(
        await storage.readSafeLines().firstWhere(
          (element) => true,
          orElse: () => '',
        ),
        '',
      );

      await storage.delete();
      await io.File(path).writeAsBytes([
        ...'1'.codeUnits,
        ...[10, 195, 9, 10],
        ...'2'.codeUnits,
      ], flush: true);

      var lines = await storage.readSafeLines().toList();
      expect(lines, ['1', '2']);
      await storage.delete();

      await io.File(path).writeAsBytes([
        ...'first\r\n2'.codeUnits,
        ...[10, 195, 9, 10, 51, 10],
        ...utf8.encode('éà'),
      ], flush: true);

      lines = await storage.readSafeLines().toList();
      expect(lines, ['first', '2', '3', 'éà']);
    });
  });
}
