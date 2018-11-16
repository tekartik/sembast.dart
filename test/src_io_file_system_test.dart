@TestOn("vm")
library sembast.io_file_system_test;

// basically same as the io runner but with extra output
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
      FileIo file = fileSystem.file("test");
      expect(file.path, "test");
    });

    test('new Directory', () {
      DirectoryIo dir = fileSystem.directory("test");
      expect(dir.path, "test");
    });

    test('isFile', () async {
      expect(await fileSystem.isFile("test"), isFalse);
      expect(await fileSystem.isDirectory("test"), isFalse);
    });

    // fs.defineTests(fileSystemContextIo);
  });
}
