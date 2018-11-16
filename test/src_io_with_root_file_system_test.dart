@TestOn("vm")
library sembast.io_file_system_test;

// basically same as the io runner but with extra output
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:sembast/src/io/io_file_system.dart';

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

    test('file', () async {
      FileIo file = fileSystem.file("file.txt");
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);
      var sink = file.openWrite();
      sink.writeln('test');
      expect(file.path, "file.txt");

      expect((await io.File(join(rootPath, file.path)).readAsLines()).first,
          'test');
    });
  });
}
