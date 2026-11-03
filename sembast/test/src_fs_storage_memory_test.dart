import 'package:path/path.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:test/test.dart';

import 'src/test_defs.dart';

void main() {
  final fs = memoryFileSystemContext.fs;
  group('fs_storage', () {
    // The memory file system stores text: a line cannot be corrupted (non
    // utf8), it is read as written. The io test writes non utf8 bytes.
    test('text lines', () async {
      var storage = FsDatabaseStorage(
        fs,
        join('.dart_tool', 'sembast', 'test', 'corrupted_non_utf8.db'),
      );
      await storage.delete();
      await storage.findOrCreate();
      await storage.appendLine(String.fromCharCodes([195, 9]));

      expect(await storage.readLines().first, String.fromCharCodes([195, 9]));
      expect(
        await storage.readSafeLines().first,
        String.fromCharCodes([195, 9]),
      );

      await storage.delete();
      await storage.appendLines([
        '1',
        String.fromCharCodes([195, 9]),
        '2',
      ]);

      var lines = await storage.readSafeLines().toList();
      expect(lines, [
        '1',
        String.fromCharCodes([195, 9]),
        '2',
      ]);
      await storage.delete();
      await storage.appendLines([
        'first\r\n2',
        String.fromCharCodes([195, 9, 10, 51]),
        'éà',
      ]);

      lines = await storage.readSafeLines().toList();
      expect(lines, [
        'first',
        '2',
        String.fromCharCodes([195, 9]),
        '3',
        'éà',
      ]);
    });
  });
}
