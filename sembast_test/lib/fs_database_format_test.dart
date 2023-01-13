library sembast.database_format_test;

import 'dart:async';

// ignore: implementation_imports
import 'package:sembast/src/database_impl.dart';
import 'package:sembast_test/fs_test_common.dart';
import 'package:sembast_test/test_common_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryFsDatabaseContext);
}

void defineTests(DatabaseTestContextFs ctx) {
  final fs = ctx.fs;
  //String getDbPath() => ctx.outPath + '.db';
  String? dbPath;
  var store = StoreRef<int, Object>.main();

  Future<List<Map<String, Object?>?>> dbFileExportToMapList() {
    return fsExportToMapList(fs, dbPath!);
  }

  Future importFromMapList(List<Map<String, Object?>> mapList) {
    return fsImportFromMapList(fs, dbPath!, mapList);
  }

  var factory = ctx.factory;
  Future<String?> prepareForDb() async {
    dbPath = dbPathFromName('fs_database_format.db');
    await ctx.factory.deleteDatabase(dbPath!);
    return dbPath;
  }

  SembastDatabase getSembastDatabase(Database db) => (db as SembastDatabase);
  Future compact(Database db) => getSembastDatabase(db).compact();

  DatabaseExportStat getExportStat(Database db) =>
      getDatabaseExportStat(getSembastDatabase(db));
  group('basic format', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);

      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1}
      ]);
      expect(getExportStat(db).lineCount, 1);
      expect(getExportStat(db).obsoleteLineCount, 0);
      expect(getExportStat(db).compactCount, 0);
    });

    test('open_version_2', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 2);
      await db.close();

      expect(await dbFileExportToMapList(), [
        {'version': 2, 'sembast': 1}
      ]);
      expect(getExportStat(db).lineCount, 1);
    });

    test('open_no_version_then_2', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 1);
      await db.close();
      db = await factory.openDatabase(dbPath!, version: 2);
      await db.close();

      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'version': 2, 'sembast': 1}
      ]);
      expect(getExportStat(db).lineCount, 2);
      expect(getExportStat(db).obsoleteLineCount, 0); // don't count meta
    });

    test('1 string record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      await store.record(1).put(db, 'hi');
      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'}
      ]);
    });

    test('1 string record delete compact', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      await store.record(1).put(db, 'hi');
      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'}
      ]);
      db = await factory.openDatabase(dbPath!);
      await store.record(1).delete(db);
      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'},
        {'key': 1, 'deleted': true}
      ]);
      db = await factory.openDatabase(dbPath!);
      await compact(db);
      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
      ]);
    });

    test('read 1 string record', () async {
      await prepareForDb();
      await importFromMapList([
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'}
      ]);
      var db = await factory.openDatabase(dbPath!);
      await db.close();
      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'}
      ]);
      expect(getExportStat(db).lineCount, 2);
      expect(getExportStat(db).obsoleteLineCount, 0); // don't count meta
    });

    test('read 1 string record _main store', () async {
      await prepareForDb();
      await importFromMapList([
        {'version': 1, 'sembast': 1},
        {'store': '_main', 'key': 1, 'value': 'hi'}
      ]);
      var db = await factory.openDatabase(dbPath!);
      expect(await store.record(1).get(db), 'hi');
      await db.close();

      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'store': '_main', 'key': 1, 'value': 'hi'}
      ]);

      db = await factory.openDatabase(dbPath!);
      await compact(db);
      await db.close();

      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'}
      ]);
      expect(getExportStat(db).lineCount, 2);
      expect(getExportStat(db).obsoleteLineCount, 0); // don't count meta
    });

    test('delete all, add all in transaction', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);

      var store = StoreRef<int, String>.main();
// Add records
      await store.addAll(db, ['hi', 'ho']);

// ...

// Instead of doing (that will create 2 transactions)
      await store.delete(db);
      await store.addAll(db, ['hi', 'ha']);

// Delete and re-add in transaction
      await db.transaction((transaction) async {
        await store.delete(transaction);
        await store.addAll(transaction, ['hi', 'hu']);
      });
      await db.close();

      expect(await dbFileExportToMapList(), [
        {'version': 1, 'sembast': 1},
        {'key': 1, 'value': 'hi'},
        {'key': 2, 'value': 'ho'},
        {'key': 1, 'deleted': true},
        {'key': 2, 'deleted': true},
        {'key': 3, 'value': 'hi'},
        {'key': 4, 'value': 'ha'},
        {'key': 3, 'deleted': true},
        {'key': 4, 'deleted': true},
        {'key': 5, 'value': 'hi'},
        {'key': 6, 'value': 'hu'}
      ]);
    });
  });
}
