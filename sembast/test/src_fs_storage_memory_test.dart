import 'dart:convert';

import 'package:path/path.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:test/test.dart';

import 'src/test_defs.dart';

void main() {
  final fs = memoryFileSystemContext.fs;
  group('fs_storage', () {
    test('corrupted', () async {
      var storage = FsDatabaseStorage(
          fs, join('.dart_tool', 'sembast', 'test', 'corrupted_non_utf8.db'));
      await storage.delete();
      await storage.findOrCreate();
      await storage.appendLine(String.fromCharCodes([195, 9]));

      try {
        await storage.readLines().first;
        fail('should fail');
      } on FormatException catch (_) {}

      expect(
          null,
          await storage
              .readSafeLines()
              .firstWhere((element) => true, orElse: () => null));

      await storage.delete();
      await storage.appendLines([
        '1',
        String.fromCharCodes([195, 9]),
        '2'
      ]);

      var lines = await storage.readSafeLines().toList();
      expect(lines, ['1', '2']);
      await storage.delete();
      await storage.appendLines([
        'first\r\n2',
        String.fromCharCodes([195, 9, 10, 51]),
        String.fromCharCodes(utf8.encode('éà'))
      ]);

      lines = await storage.readSafeLines().toList();
      expect(lines, ['first', '2', '3', 'éà']);
    });
  });
}
