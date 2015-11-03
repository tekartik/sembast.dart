library sembast.memory_file_system_impl_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/memory/memory_file_system_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:path/path.dart';
import 'test_common.dart';

main() {
  group('memory_file_system_impl', () {
    test('root', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();
      expect(fs.rootDir.segment, separator);
      expect(fs.rootDir.path, separator);
      expect(fs.rootDir.children, isEmpty);
    });

    test('current', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();
      expect(fs.currentPath, join(separator, "current"));
    });

    test('createDir', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();

      // at root
      String path = join(separator, "test");
      MemoryDirectoryImpl dir = fs.createDirectory(path);
      expect(dir.segment, "test");
      expect(dir.path, path);
      expect(dir, fs.getEntity(path));

      // sub
      dir = fs.createDirectory("test", recursive: true);
      expect(dir.segment, "test");
      expect(dir.path, join(fs.currentPath, "test"));

      // not recursive
      dir = fs.createDirectory(join("test", "sub"));
      expect(dir.segment, "sub");
      expect(dir.path, join(fs.currentPath, "test", "sub"));

      // not recursive not possible
      dir = fs.createDirectory(join("dummy", "sub"));
      expect(dir, null);
    });

    test('createDirRecursive', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();

      // at root
      MemoryDirectoryImpl dir =
          fs.createDirectory(join(separator, "test", "sub"), recursive: true);

      dir = fs.getEntity(join(separator, "test", "sub"));
      expect(dir.segment, "sub");
      expect(dir.path, join(separator, join(separator, "test", "sub")));

      // check top folder has been created
      dir = fs.getEntity(join(separator, "test"));
      expect(dir.segment, "test");
      expect(dir.path, join(separator, join(separator, "test")));
      expect(dir.children.containsKey("sub"), isTrue);
    });

    test('deleteDir', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();

      // at root
      String path = join(separator, "test");
      MemoryDirectoryImpl dir = fs.createDirectory(path);

      // get it
      dir = fs.getEntity(path);
      expect(dir.segment, "test");
      expect(dir.path, join(separator, "test"));

      fs.delete(path);
      dir = fs.getEntity(path);
      expect(dir, null);

      // dummy
      try {
        fs.delete(join(separator, "dummy"));
        fail("should fail");
      } on FileSystemException catch (e) {
        expect(e.osError.errorCode, 2);
      }

      // not empty
      path = join(separator, "test", "sub");
      dir = fs.createDirectory(path, recursive: true);
      try {
        fs.delete(join(separator, "test"));
        fail("should fail");
      } on FileSystemException catch (e) {
        expect(e.osError.errorCode, 39);
      }

      fs.delete(join(separator, "test"), recursive: true);
    });

    test('createFile', () {
      MemoryFileSystemImpl fs = new MemoryFileSystemImpl();

      // at root
      String path = join(separator, "test");
      MemoryFileImpl dir = fs.createFile(path);
      expect(dir.segment, "test");
      expect(dir.path, path);
      expect(dir, fs.getEntity(path));

      // sub
      dir = fs.createFile("test", recursive: true);
      expect(dir.segment, "test");
      expect(dir.path, join(fs.currentPath, "test"));

      // Create dir
      fs.createDirectory(join(separator, "dir"), recursive: true);

      // not recursive
      dir = fs.createFile(join(separator, "dir", "sub"));
      expect(dir.segment, "sub");
      expect(dir.path, join(separator, "dir", "sub"));

      // not recursive not possible
      dir = fs.createFile(join("dummy", "sub"));
      expect(dir, null);
    });
  });
}
