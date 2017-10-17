@TestOn("vm")
library sembast.test.io_test;

import 'dart:async';
import 'dart:convert';
import 'io_test_common.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'test_common.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'package:sembast/src/file_system.dart';
import 'dart:io' as io;
void main() {
  group("io", () {
    test('fs', () {
      expect(ioDatabaseFactory.fs, ioFileSystem);
    });

    IoFileSystemTestContext ctx = ioFileSystemContext;
    FileSystem fs = ctx.fs;

    group('format', () {
      String getDbPath() => ctx.outPath + ".db";
      String dbPath;

      Future<String> prepareForDb() async {
        dbPath = getDbPath();
        await fs.newDirectory(dirname(dbPath)).create(recursive: true).catchError((_) {});
        await fs.newFile(dbPath).delete().catchError((_) {});
        return dbPath;
      }

      test('missing new line', () async {
        await prepareForDb();

        await new io.File(dbPath).writeAsString(JSON.encode({"version": 2, "sembast": 1}));
        Database db = await ioDatabaseFactory.openDatabase(dbPath);
        expect(db.version, 2);

        await db.put("value", "key");

        //print(await new io.File(dbPath).readAsString());

        try {
          await db.reOpen();
          fail("should fail");
        } on FormatException catch (_) {
          await db.reOpen(mode: DatabaseMode.NEVER_FAILS);
          // version cannot be read anymore...
          expect(db.version, 1);
        }
        db.close();
      });

      test('missing new line after 1 record', () async {
        await prepareForDb();

        await new io.File(dbPath).writeAsString(
            JSON.encode({"version": 2, "sembast": 1}) + "\n"
                + JSON.encode({'key': 1, 'value': 'test1'}) + "\n"
            + JSON.encode({'key': 2, 'value': 'test2'}));
        Database db = await ioDatabaseFactory.openDatabase(dbPath);
        expect(db.version, 2);

        await db.put("value3");

        //print(await new io.File(dbPath).readAsString());

        try {
          await db.reOpen();
          fail("should fail");
        } on FormatException catch (_) {
          await db.reOpen(mode: DatabaseMode.NEVER_FAILS);
          List<String> lines = await readContent(fs, dbPath);
          // Only the first line remains
          expect(lines.length, 2);
          expect(JSON.decode(lines[1]), {'key': 1, 'value': 'test1'});
        }
        db.close();
      });
    });
  });
}
