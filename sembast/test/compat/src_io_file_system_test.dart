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
  var fileSystem = FileSystemIo();
  group('io', () {
    setUp(() {});

    tearDown(() {});

    test('newFile', () {
      final file = fileSystem.file("test") as FileIo;
      expect(file.path, "test");
    });

    test('new Directory', () {
      final dir = fileSystem.directory("test") as DirectoryIo;
      expect(dir.path, "test");
    });

    test('file location', () async {
      var path = join('.dart_tool', 'sembast', 'test', 'file_system_io');
      final file = fileSystem.file(path);
      expect(file.path, path);
      io.File ioFile = io.File(path);
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

    test('isFile', () async {
      expect(await fileSystem.isFile("test"), isFalse);
      expect(await fileSystem.isDirectory("test"), isTrue);
    });

    // fs.defineTests(fileSystemContextIo);
  });
}
