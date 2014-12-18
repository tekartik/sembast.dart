library sembast.io_file_system_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:tekartik_test/test_utils_io.dart';
import 'package:sembast/src/file_system.dart';
import 'dart:async';
import 'package:path/path.dart';

String filePath(String name) => join(outDataPath, name);

void defineTests(FileSystem fs) {

  File nameFile(String name) => fs.newFile(filePath(name));

  Future<File> createFile(File file) {
    return file.create(recursive: true).then((File file_) {
      expect(file, file_);
      return file_;
    });
  }

  Future<File> createFileName(String name) => createFile(nameFile(name));

  Future expectFileExists(File file, [bool exists = true]) {
    return file.exists().then((bool exists_) {
      expect(exists_, exists);
    });
  }

  Future<File> expectFileNameExists(String name, [bool exists = true]) => expectFileExists(nameFile(name), exists);


  Future<File> deleteFile(File file) {
    return file.delete(recursive: true).then((File file_) {
      expect(file, file_);
      return file_;
    });
  }

  Future<Directory> deleteDirectory(Directory dir) {
    return dir.delete(recursive: true).then((Directory dir_) {
      expect(dir, dir_);
      return dir_;
    });
  }
  Future clearOutFolder() {
    return deleteDirectory(fs.newDirectory(outDataPath)).catchError((FileSystemException e, st) {
      //devPrint("${e}\n${st}");
    });
  }

  setUp(() {
    return clearOutFolder();
  });

  tearDown(() {
  });


  solo_group('fs', () {

    test('file exists', () {
      return expectFileNameExists("test", false);
    });

    test('file create', () {
      return createFileName("test").then((File file) {
        return file.exists().then((bool exists) {
          expect(exists, true);
        });
      });
    });

    test('file delete', () {
      File file = nameFile("test");
      return deleteFile(file).then((_) {
      }, onError: (FileSystemException e) {
      }).then((_) {
        return expectFileExists(file, false).then((_) {
          return createFile(file);
        }).then((_) {
          return expectFileExists(file, true);
        });
      });
    });

  });


}
