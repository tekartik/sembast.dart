library;

import 'dart:async';

import 'package:path/path.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;
  group('open', () {
    test('exists', () async {
      var path = dbPathFromName('open/exists.db');

      await factory.deleteDatabase(path);
      expect(await factory.databaseExists(path), isFalse);
      var db = await factory.openDatabase(path);
      expect(await factory.databaseExists(path), isTrue);
      expect(db.version, 1);
      await db.close();
      await factory.deleteDatabase(path);
      expect(await factory.databaseExists(path), isFalse);
    });
    test('no_version', () async {
      var path = dbPathFromName('open/no_version.db');

      await factory.deleteDatabase(path);
      var db = await factory.openDatabase(
        path,
        onVersionChanged: (db, oldVersion, newVersion) async {
          expect(oldVersion, 0);
          expect(newVersion, 1);
          expect(db.version, 0);
        },
      );
      expect(db.version, 1);
      await db.close();
    });
    test('version', () async {
      var path = dbPathFromName('open/version.db');

      await factory.deleteDatabase(path);

      var db = await factory.openDatabase(
        path,
        version: 1,
        onVersionChanged: (db, oldVersion, newVersion) async {
          expect(oldVersion, 0);
          expect(db.version, 0);
          expect(newVersion, 1);
        },
      );
      expect(db.version, 1);
      await db.close();

      db = await factory.openDatabase(
        path,
        version: 2,
        onVersionChanged: (db, oldVersion, newVersion) async {
          expect(oldVersion, 1);
          expect(newVersion, 2);
          expect(db.version, 1);
        },
      );
      expect(db.version, 2);
    });

    test('re_open', () async {
      var path = dbPathFromName('open/re_open.db');

      await factory.deleteDatabase(path);

      var db = await factory.openDatabase(path);
      expect(db.version, 1);
      await db.close();
      db = await factory.openDatabase(path);
      expect(db.version, 1);
      await db.close();
    });

    /// Edge case,
    /// While it fails on native due to not waiting for the transaction
    /// to complete, it brings a weird behavior on sembase where the old
    /// open helper option remains.
    test('initial_empty_re_open', () async {
      var path = dbPathFromName('open/initial_empty_re_open.db');
      var store = StoreRef<int, int>.main();
      await factory.deleteDatabase(path);

      var db = await factory.openDatabase(
        path,
        version: 2,
        mode: DatabaseMode.empty,
      );
      expect(db.version, 2);
      await store.record(1).put(db, 2);
      // ignore: unawaited_futures
      db.close();
      try {
        db = await factory.openDatabase(path);
      } catch (e) {
        // Happens on idb, exit
        return;
      }
      expect(db.version, 2);
      expect(await store.record(1).get(db), 2);
      await db.close();
    });

    test('compacting during open', () async {
      // Deleting all the records during onVersionChanged could trigger
      // a compact that hangs the database
      // fixed in 1.16.0+1
      var store = StoreRef<int, int>.main();

      Future<Database> openDatabase(String path, int version) async {
        return await factory.openDatabase(
          path,
          version: version,
          onVersionChanged: (db, oldVersion, newVersion) async {
            if (oldVersion == 1 && newVersion == 2) {
              await db.transaction((txn) async {
                var records = await store.find(txn);

                for (var item in records) {
                  await store.delete(
                    txn,
                    finder: Finder(filter: Filter.byKey(item.key)),
                  );
                }
              });
            }
          },
        );
      }

      var path = dbPathFromName('open/compacting_during_open.db');

      await factory.deleteDatabase(path);

      var db = await openDatabase(path, 1);
      // Add 21 records
      await db.transaction((txn) async {
        for (var i = 1; i < 21; i++) {
          await store.add(txn, i);
        }
      });
      await db.close();

      db = await openDatabase(path, 2);
      await db.close();
    });

    test('on_change_version_error', () async {
      final path = dbPathFromName(join('open', 'on_change_version_error.db'));

      Future<Database> openDatabase(String path) => factory.openDatabase(path);

      Future<Database> openDatabaseV1(String path) =>
          factory.openDatabase(path, version: 1);

      FutureOr changeFrom1To2(Database db, int oldVersion, int newVersion) {
        if (oldVersion == 1) {
          throw UnimplementedError();
        }
      }

      Future<Database> openDatabaseV2(String path) => factory.openDatabase(
        path,
        version: 2,
        onVersionChanged: changeFrom1To2,
      );

      Database? db;

      await factory.deleteDatabase(path);

      // open v1
      db = await openDatabaseV1(path);
      expect(db.version, 1); // true
      await db.close();

      db = null;
      try {
        // open v1 and update to v2, contains throw UnimplementedError();
        db = await openDatabaseV2(path);
        fail('should fail');
      } on UnimplementedError catch (_) {}
      expect(db, isNull);

      // open without version
      db = await openDatabase(path);
      expect(db.version, 1); // true
      await db.close();

      // open  without version now
      db = await openDatabase(path);
      expect(db.version, 1); // false - Why?
      await db.close();
    });

    test('read only', () async {
      final dbPath = dbPathFromName(join('open', 'read_only.db'));
      await factory.deleteDatabase(dbPath);
      try {
        await factory.openDatabase(
          dbPath,
          mode: DatabaseMode.readOnly,
          version: 1,
        );
        fail('Should fail');
      } on ArgumentError catch (_) {}
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      var db = await factory.openDatabase(dbPath);
      await record.put(db, 'hi');
      await db.close();

      db = await factory.openDatabase(dbPath, mode: DatabaseMode.readOnly);

      var record2 = store.record(2);
      expect(await record.get(db), 'hi');
      expect(await record2.get(db), isNull);
      try {
        await record2.put(db, 'ho');
        fail('should fail');
      } on DatabaseException catch (_) {
        // Read-only database
        // print(_);
      }
      expect(await record2.get(db), isNull); // ! read-only but not in memory
      await db.close();
      db = await factory.openDatabase(dbPath, mode: DatabaseMode.readOnly);
      // expect(await record2.get(db), isNull); to test
      await db.close();
    });
  });
}
