library sembast.io_file_system_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'src_file_system_test.dart' as fs;

void main() {
  useVMConfiguration();
  defineTests();
}

void defineTests() {

  group('io', () {

    setUp(() {
    });

    tearDown(() {
    });

    test('newFile', () {
      File file = new File("test");
      expect(file.path, "test");
    });
    
    test('new Directory', () {
          Directory dir = new Directory("test");
          expect(dir.path, "test");
        });

    test('isFile', () {
      return FileSystemEntity.isFile("test").then((bool isFile) {

      });
    });
  });
  
  fs.defineTests(ioFileSystem);
}
