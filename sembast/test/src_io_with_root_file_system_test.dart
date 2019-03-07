@TestOn("vm")
library sembast.io_file_system_test;

// basically same as the io runner but with extra output
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:sembast/src/io/file_system_io.dart';

import 'test_common.dart';

void main() {
  defineTests();
}

void defineTests() {
  String rootPath = join('.dart_tool', 'sembast', 'test', 'with_root');
  var fileSystem = FileSystemIo(rootPath: rootPath);
  group('io', () {
    setUp(() {});

    tearDown(() {});

    test('file location', () async {
      final file = fileSystem.file("file.txt");
      expect(file.path, "file.txt");
      io.File ioFile = io.File(join(rootPath, "file.txt"));
      if (await file.exists()) {
        await file.delete();
      }

      expect(ioFile.existsSync(), isFalse);

      await file.create(recursive: true);
      var sink = file.openWrite();
      sink.writeln('test');
      await sink.close();

      expect((await ioFile.readAsLines()).first, 'test');
    });
  });
}
