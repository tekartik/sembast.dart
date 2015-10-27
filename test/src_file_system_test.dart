library sembast.io_file_system_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/file_system.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'dart:convert';
import 'test_common.dart';

main() {
  group('memory', () {
    defineTests(memoryFileSystemContext);
  });
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  /*
  TODO

  String outDataPath = testOutPath(fs);
*/

  String namePath(String name) => join(ctx.outPath, name);

  File nameFile(String name) => fs.newFile(namePath(name));
  Directory nameDir(String name) => fs.newDirectory(namePath(name));

  Future<File> createFile(File file) {
    return file.create(recursive: true).then((File file_) {
      expect(file, file_);
      return file_;
    });
  }

  Future<File> createFileName(String name) => createFile(nameFile(name));

  Future expectDirExists(Directory dir, [bool exists = true]) async {
    bool exists_ = await dir.exists();
    expect(exists_, exists);
  }

  Future expectFileExists(File file, [bool exists = true]) async {
    bool exists_ = await file.exists();
    expect(exists_, exists);
  }

  Future<File> expectFileNameExists(String name, [bool exists = true]) =>
      expectFileExists(nameFile(name), exists);

  Stream<List<int>> openRead(File file) {
    return file.openRead();
  }

  Stream<String> openReadLines(File file) {
    return openRead(file).transform(UTF8.decoder).transform(new LineSplitter());
  }

  IOSink openWrite(File file) {
    return file.openWrite(mode: FileMode.WRITE);
  }

  IOSink openAppend(File file) {
    return file.openWrite(mode: FileMode.APPEND);
  }

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
    return deleteDirectory(fs.newDirectory(ctx.outPath))
        .catchError((FileSystemException e, st) {
      //devPrint("${e}\n${st}");
    });
  }

  Future<List<String>> readContent(File file) {
    List<String> content = [];
    return openReadLines(file).listen((String line) {
      content.add(line);
    }).asFuture(content);
  }

  Future writeContent(File file, List<String> content) {
    IOSink sink = openWrite(file);
    content.forEach((String line) {
      sink.writeln(line);
    });
    return sink.close();
  }

  Future appendContent(File file, List<String> content) {
    IOSink sink = openAppend(file);
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
        return fs.type(namePath("test")).then((FileSystemEntityType type) {
          expect(type, FileSystemEntityType.NOT_FOUND);
        }).then((_) {
          return fs.isFile(namePath("test")).then((bool isFile) {
            expect(isFile, false);
          });
        }).then((_) {
          return fs.isDirectory(namePath("test")).then((bool isFile) {
            expect(isFile, false);
          });
        });
      });
    });

    group('dir', () {
      test('dir exists', () async {
        await clearOutFolder();
        await expectDirExists(nameDir("test"), false);
      });

      test('dir create', () async {
        await clearOutFolder();
        Directory dir = nameDir("test");
        Directory dir2 = nameDir("test");
        expect(await fs.isDirectory(dir.path), isFalse);
        await dir.create(recursive: true);
        await expectDirExists(dir, true);
        await expectDirExists(dir2, true);
        expect(await fs.isDirectory(dir.path), isTrue);

        // create another object
        dir = nameDir("test");
        await expectDirExists(dir, true);

        // second time fine too
        await dir.create(recursive: true);
      });

      test('fileSystem', () {
        Directory dir = nameDir("test");
        expect(dir.fileSystem, fs);
      });

      test('sub dir create', () async {
        await clearOutFolder();
        Directory mainDir = nameDir("test");
        Directory subDir = fs.newDirectory(join(mainDir.path, "test"));

        return subDir.create(recursive: true).then((_) {
          return expectDirExists(mainDir, true).then((_) {});
        });
      });

      test('dir delete', () async {
        await clearOutFolder();
        Directory dir = nameDir("test");
        return dir.delete(recursive: true).then((_) {
          fail('');
        }, onError: (FileSystemException e) {}).then((_) {
          return expectDirExists(dir, false);
        }).then((_) {
          return dir.create(recursive: true).then((_) {
            return expectDirExists(dir, true).then((_) {});
          }).then((_) {
            return dir.delete(recursive: true).then((_) {
              return expectDirExists(dir, false);
            });
          });
        });
      });

      test('sub dir delete', () async {
        await clearOutFolder();
        Directory mainDir = nameDir("test");
        Directory subDir = nameDir(join(mainDir.path, "test"));

        return subDir.create(recursive: true).then((_) {
          return mainDir.delete(recursive: true).then((_) {
            return expectDirExists(subDir, false);
          });
        });
      });
    });
    group('file', () {
      test('file exists', () async {
        await clearOutFolder();
        return expectFileNameExists("test", false);
      });

      test('file create', () async {
        await clearOutFolder();
        File file = nameFile("test");
        expect(await file.exists(), isFalse);
        expect(await fs.isFile(file.path), isFalse);
        File createdFile = await createFile(file);
        expect(await fs.isFile(file.path), isTrue);
        expect(await createdFile.exists(), isTrue);
        expect(await file.exists(), isTrue);

        // create twice ok
        File createdFile2 = await createFile(file);
        expect(await createdFile2.exists(), isTrue);
      });

      test('file delete', () async {
        await clearOutFolder();
        File file = nameFile("test");
        return deleteFile(file).then((_) {
          fail('');
        }, onError: (FileSystemException e) {}).then((_) {
          return expectFileExists(file, false).then((_) {
            return createFile(file);
          }).then((_) {
            return expectFileExists(file, true);
          });
        });
      });

      test('file delete 2', () async {
        await clearOutFolder();
        File file = nameFile(join("sub", "test"));
        return deleteFile(file).then((_) {
          fail('');
        }, onError: (FileSystemException e) {}).then((_) {
          return expectFileExists(file, false).then((_) {
            return createFile(file);
          }).then((_) {
            return expectFileExists(file, true);
          });
        });
      });

      test('open read 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        bool ok;
        return openRead(file).listen((_) {
          fail('');
        }, onError: (e) {
          //devPrint(e);
        }, onDone: () {
          // devPrint('done');
        }).asFuture().catchError((e) {
          //devPrint(e);
          ok = true;
        }).then((_) {
          expect(ok, isTrue);
        });
//        return openRead(file).listen((_) {
//          fail('');
//        }, onError: (e) {
//          devPrint(e);
//        }).asFuture();
      });

      test('open write 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        IOSink sink = openWrite(file);
        //sink.writeln("test");
        return sink.close().then((_) {
          fail('');
        }, onError: (FileSystemException e, st) {
          //devPrint("${e}");
        });
      });

      test('open write 2', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          IOSink sink = openWrite(file);
          sink.writeln("test");
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ["test"]);
            });
          });
        });
      });

      test('open write 3', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return writeContent(file, ["test1"]).then((_) {
            // override existing
            return writeContent(file, ["test2"]).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ["test2"]);
              });
            });
          });
        });
      });

      test('open append 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        IOSink sink = openAppend(file);
        //sink.writeln("test");
        return sink.close().then((_) {
          fail('');
        }, onError: (FileSystemException e, st) {
          //devPrint("${e}");
        });
      });

      test('open append 2', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          IOSink sink = openAppend(file);
          sink.writeln("test");
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ["test"]);
            });
          });
        });
      });

      test('open append 3', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return writeContent(file, ["test1"]).then((_) {
            return appendContent(file, ["test2"]).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ["test1", "test2"]);
              });
            });
          });
        });
      });

      test('rename', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return file.rename(namePath("test2")).then((File renamed) {
            return expectFileExists(renamed).then((_) {
              return expectFileExists(file, false).then((_) {});
            });
          });
        });
      });

      test('rename to existing', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          String path2 = namePath("test2");
          return createFile(fs.newFile(path2)).then((_) {
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
        File file = await createFileName("test");
        await writeContent(file, ["test1"]);
        String path2 = namePath("test2");
        File file2 = await file.rename(path2);
        List<String> content = await readContent(file2);
        expect(content, ["test1"]);
      });

      test('create_write_then_create', () async {
        await clearOutFolder();
        File file = nameFile("test");
        file = await createFile(file);
        IOSink sink = openWrite(file);
        sink.writeln("test");
        await sink.close();

        // create again
        file = await createFile(file);
        List<String> lines = [];
        await openReadLines(file).listen((String line) {
          lines.add(line);
        }).asFuture();
        expect(lines, ['test']);
      });
    });
  });
}
