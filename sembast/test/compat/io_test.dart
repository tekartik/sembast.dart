@TestOn("vm")
library sembast.test.io_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/io/database_factory_io.dart' as impl;
import 'package:sembast/src/io/file_system_io.dart';

import '../io_test_common.dart';
import '../test_common.dart';

void main() {
  group("io", () {
    test('fs', () {
      expect((databaseFactoryIo as impl.DatabaseFactoryIo).fs,
          const TypeMatcher<FileSystemIo>());
      final fs =
          (databaseFactoryIo as impl.DatabaseFactoryIo).fs as FileSystemIo;
      expect(fs.rootPath, isNull);
    });

    FileSystemTestContextIo ctx = fileSystemContextIo;
    FileSystem fs = ctx.fs;

    group('format', () {
      String dbPath;

      Future<String> prepareForDb() async {
        dbPath = dbPathFromName('compat/io/format.db');
        await fs
            .directory(dirname(dbPath))
            .create(recursive: true)
            .catchError((_) {});
        await fs.file(dbPath).delete().catchError((_) {});
        return dbPath;
      }

      test('missing new line', () async {
        await prepareForDb();

        await io.File(dbPath)
            .writeAsString(json.encode({"version": 2, "sembast": 1}));
        Database db = await databaseFactoryIo.openDatabase(dbPath);
        expect(db.version, 2);

        await db.put("value", "key");

        //print(await new io.File(dbPath).readAsString());

        try {
          await reOpen(db, mode: DatabaseMode.create);
          fail("should fail");
        } on FormatException catch (_) {
          await reOpen(db, mode: DatabaseMode.neverFails);
          // version cannot be read anymore...
          expect(db.version, 1);
        }
        await db.close();
      });

      test('missing new line after 1 record', () async {
        await prepareForDb();

        await io.File(dbPath).writeAsString(
            json.encode({"version": 2, "sembast": 1}) +
                "\n" +
                json.encode({'key': 1, 'value': 'test1'}) +
                "\n" +
                json.encode({'key': 2, 'value': 'test2'}));
        Database db = await databaseFactoryIo.openDatabase(dbPath);
        expect(db.version, 2);

        await db.put("value3");

        //print(await new io.File(dbPath).readAsString());

        try {
          await reOpen(db, mode: DatabaseMode.create);
          fail("should fail");
        } on FormatException catch (_) {
          await reOpen(db, mode: DatabaseMode.neverFails);
          List<String> lines = await readContent(fs, dbPath);
          // Only the first line remains
          expect(lines.length, 2);
          expect(json.decode(lines[1]), {'key': 1, 'value': 'test1'});
        }
        await db.close();
      });
    });
  });
}
