library sembast.io_file_system_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart';
import 'package:sembast/src/file_system.dart';

import 'test_common.dart';

void main() {
  group('memory', () {
    defineTests(memoryFileSystemContext);
  });
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  /*
  TODO

  String outDataPath = testOutPath(fs);
*/

  final rootPath = dbPathFromName('compat/src_file_system');
  String namePath(String name) => join(rootPath, name);

  File nameFile(String name) => fs.file(namePath(name));
  Directory nameDir(String name) => fs.directory(namePath(name));

  Future<File> createFile(File file) async {
    final createdFile = await file.create(recursive: true);
    expect(file, createdFile); // identical
    return createdFile;
  }

  Future<File> createFileName(String name) => createFile(nameFile(name));

  Future expectDirExists(Directory dir, [bool exists = true]) async {
    final dirExists = await dir.exists();
    expect(dirExists, exists);
  }

  Future expectFileExists(File file, [bool exists = true]) async {
    final fileExists = await file.exists();
    expect(fileExists, exists);
  }

  Future expectFileNameExists(String name, [bool exists = true]) =>
      expectFileExists(nameFile(name), exists);

  Stream<List<int>> openRead(File file) {
    return file.openRead();
  }

  Stream<String> openReadLines(File file) {
    return utf8.decoder.bind(openRead(file)).transform(const LineSplitter());
  }

  IOSink openWrite(File file) {
    return file.openWrite(mode: FileMode.write);
  }

  IOSink openAppend(File file) {
    return file.openWrite(mode: FileMode.append);
  }

  Future<File> deleteFile(File file) async {
    var deletedFile = await file.delete(recursive: true) as File;
    expect(file, deletedFile);
    return deletedFile;
  }

  Future<Directory> deleteDirectory(Directory dir) async {
    var directory = (await dir.delete(recursive: true)) as Directory;
    expect(dir, directory);
    return directory;
  }

  Future clearOutFolder() async {
    try {
      await deleteDirectory(fs.directory(rootPath));
    } catch (_) {}
  }

  Future<List<String>> readContent(File file) {
    final content = <String>[];
    return openReadLines(file).listen((String line) {
      content.add(line);
    }).asFuture(content);
  }

  Future writeContent(File file, List<String> content) {
    final sink = openWrite(file);
    content.forEach((String line) {
      sink.writeln(line);
    });
    return sink.close();
  }

  Future appendContent(File file, List<String> content) {
    final sink = openAppend(file);
    content.forEach((String line) {
      sink.writeln(line);
    });
    return sink.close();
  }

  setUp(() {
    // return clearOutFolder();
  });

  tearDown(() {});

  group('fs', () {
    group('file_system', () {
      test('currentDirectory', () {
        expect(fs.currentDirectory, isNotNull);
      });

      test('scriptFile', () {
        //expect(fs.scriptFile, isNotNull);
      });

      test('type', () async {
        await clearOutFolder();
        var type = await fs.type(namePath('test'));

        expect(type, FileSystemEntityType.notFound);

        expect(await fs.isFile(namePath('test')), false);
        expect(await fs.isDirectory(namePath('test')), false);
      });
    });

    group('dir', () {
      test('new', () {
        var dir = fs.directory('dummy');
        expect(dir.path, 'dummy');
        dir = fs.directory(r'\root/dummy');
        expect(dir.path, r'\root/dummy');
        dir = fs.directory(r'\');
        expect(dir.path, r'\');
        dir = fs.directory(r'');
        expect(dir.path, r'');
      });
      test('dir exists', () async {
        await clearOutFolder();
        await expectDirExists(nameDir('test'), false);
      });

      test('dir create', () async {
        await clearOutFolder();
        var dir = nameDir('test');
        final dir2 = nameDir('test');
        expect(await fs.isDirectory(dir.path), isFalse);
        await dir.create(recursive: true);
        await expectDirExists(dir, true);
        await expectDirExists(dir2, true);
        expect(await fs.isDirectory(dir.path), isTrue);

        // create another object
        dir = nameDir('test');
        await expectDirExists(dir, true);

        // second time fine too
        await dir.create(recursive: true);
      });

      test('fileSystem', () {
        final dir = nameDir('test');
        expect(dir.fileSystem, fs);
      });

      test('sub dir create', () async {
        await clearOutFolder();
        final mainDir = nameDir('test');
        final subDir = fs.directory(join(mainDir.path, 'test'));

        return subDir.create(recursive: true).then((_) {
          return expectDirExists(mainDir, true).then((_) {});
        });
      });

      test('dir delete', () async {
        await clearOutFolder();
        final dir = nameDir('test');

        try {
          await dir.delete(recursive: true);
          fail('shoud fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/dir/dir delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }

        await expectDirExists(dir, false);

        await dir.create(recursive: true);
        await expectDirExists(dir, true);
        await dir.delete(recursive: true);
        await expectDirExists(dir, false);
      });

      test('sub dir delete', () async {
        await clearOutFolder();
        final mainDir = nameDir('test');
        final subDir = fs.directory(join(mainDir.path, 'test'));

        // not recursive
        await subDir.create(recursive: true);

        try {
          await mainDir.delete();
          fail('shoud fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/dir/sub dir delete/test' (OS Error: Directory not empty, errno = 39)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: Directory is not empty, errno = 39)
        }
        await expectDirExists(mainDir, true);
        await mainDir.delete(recursive: true);
        await expectDirExists(mainDir, false);
      });
    });
    group('file', () {
      test('new', () {
        var file = fs.file('dummy');
        expect(file.path, 'dummy');
        file = fs.file(r'\root/dummy');
        expect(file.path, r'\root/dummy');
        file = fs.file(r'\');
        expect(file.path, r'\');
        file = fs.file(r'');
        expect(file.path, r'');
      });
      test('file exists', () async {
        await clearOutFolder();
        return expectFileNameExists('test', false);
      });

      test('file create', () async {
        await clearOutFolder();
        final file = nameFile('test');
        expect(await file.exists(), isFalse);
        expect(await fs.isFile(file.path), isFalse);
        final createdFile = await createFile(file);
        expect(await fs.isFile(file.path), isTrue);
        expect(await createdFile.exists(), isTrue);
        expect(await file.exists(), isTrue);

        // create twice ok
        final createdFile2 = await createFile(file);
        expect(await createdFile2.exists(), isTrue);
      });

      test('file delete', () async {
        await clearOutFolder();
        final file = nameFile('test');

        try {
          await deleteFile(file);
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/file delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        await expectFileExists(file, false);
        await createFile(file);
        await expectFileExists(file, true);
        await deleteFile(file);
        await expectFileExists(file, false);
      });

      test('file delete 2', () async {
        await clearOutFolder();
        final file = nameFile(join('sub', 'test'));

        try {
          await deleteFile(file);
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/file delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        await expectFileExists(file, false);
        await createFile(file);
        await expectFileExists(file, true);
        await deleteFile(file);
        await expectFileExists(file, false);
      });

      test('open read 1', () async {
        await clearOutFolder();
        final file = nameFile('test');
        Object? e;
        await openRead(file)
            .listen((_) {}, onError: (_) {
              print(_);
            })
            .asFuture()
            .catchError((e2) {
              // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open read 1/test' (OS Error: No such file or directory, errno = 2)
              // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
              e = e2;
            });
        expect(e, isNotNull);
      });

      test('open write 1', () async {
        await clearOutFolder();
        final file = nameFile('test');
        final sink = openWrite(file);
        //sink.writeln('test');
        try {
          await sink.close();
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open write 1/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
      });

      test('open write 2', () async {
        await clearOutFolder();
        return createFileName('test').then((File file) {
          final sink = openWrite(file);
          sink.writeln('test');
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ['test']);
            });
          });
        });
      });

      test('open write 3', () async {
        await clearOutFolder();
        return createFileName('test').then((File file) {
          return writeContent(file, ['test1']).then((_) {
            // override existing
            return writeContent(file, ['test2']).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ['test2']);
              });
            });
          });
        });
      });

      test('open append 1', () async {
        await clearOutFolder();
        final file = nameFile('test');
        final sink = openAppend(file);
        //sink.writeln('test');
        try {
          await sink.close();
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open write 1/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
      });

      test('open append 2', () async {
        await clearOutFolder();
        return createFileName('test').then((File file) {
          final sink = openAppend(file);
          sink.writeln('test');
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ['test']);
            });
          });
        });
      });

      test('open append 3', () async {
        await clearOutFolder();
        return createFileName('test').then((File file) {
          return writeContent(file, ['test1']).then((_) {
            return appendContent(file, ['test2']).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ['test1', 'test2']);
              });
            });
          });
        });
      });

      test('rename', () async {
        await clearOutFolder();
        var file = await createFileName('test');
        var renamed = await file.rename(namePath('test2'));
        await expectFileExists(renamed);
        await expectFileExists(file, false);
      });

      test('rename to existing', () async {
        await clearOutFolder();
        return createFileName('test').then((File file) {
          final path2 = namePath('test2');
          return createFile(fs.file(path2)).then((_) {
            return file.rename(path2).then((File renamed) {
              //devPrint(renamed);
            }).catchError((e) {
              //devPrint(e);
            });
          });
        });
      });

      test('rename and read', () async {
        await clearOutFolder();
        final file = await createFileName('test');
        await writeContent(file, ['test1']);
        final path2 = namePath('test2');
        final file2 = await file.rename(path2);
        final content = await readContent(file2);
        expect(content, ['test1']);
      });

      test('create_write_then_create', () async {
        await clearOutFolder();
        var file = nameFile('test');
        file = await createFile(file);
        final sink = openWrite(file);
        sink.writeln('test');
        await sink.close();

        // create again
        file = await createFile(file);
        final lines = <String>[];
        await openReadLines(file).listen((String line) {
          lines.add(line);
        }).asFuture();
        expect(lines, ['test']);
      });

      test('deep_create_write_then_create', () async {
        await clearOutFolder();
        var file = nameFile(join('test', 'sub', 'yet another'));
        file = await createFile(file);
        final sink = openWrite(file);
        sink.writeln('test');
        await sink.close();

        // create again
        file = await createFile(file);
        final lines = <String>[];

        file = nameFile(join('test', 'sub', 'yet another'));
        await openReadLines(file).listen((String line) {
          lines.add(line);
        }).asFuture();
        expect(lines, ['test']);
      });
    });
  });
}
