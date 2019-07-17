library sembast.database_test;

// basically same as the io runner but with extra output
import 'package:pedantic/pedantic.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  DatabaseFactory factory = ctx.factory;
  String dbPath;
  var store = StoreRef.main();

  group('database', () {
    dbPath = dbPathFromName('compat/database.db');

    group('open', () {
      Database db;

      setUp(() async {
        await factory.deleteDatabase(dbPath);
      });

      tearDown(() {
        return db?.close();
      });

      test('open_no_version', () async {
        var db = await factory.openDatabase(dbPath);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_existing_no_version', () async {
        try {
          await factory.openDatabase(dbPath, mode: DatabaseMode.existing);
          fail("should fail");
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errDatabaseNotFound);
        }
      });

      test('open_version', () async {
        var db = await factory.openDatabase(dbPath, version: 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_twice_no_close', () async {
        var db = await factory.openDatabase(dbPath, version: 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        var db2 = await factory.openDatabase(dbPath, version: 1);
        // behavior is unexpected from now...
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db2.close();
      });

      test('open_twice_same_instance', () async {
        var futureDb1 = factory.openDatabase(dbPath);
        var futureDb2 = factory.openDatabase(dbPath);
        var db1 = await futureDb1;
        var db2 = await futureDb2;
        var db3 = await factory.openDatabase(dbPath);
        expect(db1, db2);
        expect(db1, db3);
        expect(identical(db1, db3), isTrue);
        await db1.close();
      });

      test('open_close_open', () async {
        var db = await factory.openDatabase(dbPath);
        var record = store.record(1);
        try {
          // don't await to make sure it gets written at some point
          unawaited(db.transaction((txn) async {
            await Future.delayed(const Duration(milliseconds: 10));
            await record.put(txn, 'test');
          }));
          unawaited(db.close());
          db = await factory.openDatabase(dbPath);
          expect(await record.get(db), 'test');
          // Do it again
          // don't await to make sure it gets written at some point
          unawaited(db.transaction((txn) async {
            await Future.delayed(const Duration(milliseconds: 10));
            await record.put(txn, 'test2');
          }));
          unawaited(db.close());
          db = await factory.openDatabase(dbPath);
          expect(await record.get(db), 'test2');

          await db.close();
          db = await factory.openDatabase(dbPath);
          expect(await record.get(db), 'test2');
        } finally {
          await db.close();
        }
      });
    });

    group('onVersionChanged', () {
      Database db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        return db?.close();
      });

      test('open_no_version', () async {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        void _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        var db = await factory.openDatabase(dbPath,
            onVersionChanged: _onVersionChanged);
        expect(_oldVersion, 0);
        expect(_newVersion, 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('open_version', () async {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        void _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        var db = await factory.openDatabase(dbPath,
            version: 1, onVersionChanged: _onVersionChanged);

        expect(_oldVersion, 0);
        expect(_newVersion, 1);
        expect(db.version, 1);
        expect(db.path, endsWith(dbPath));
        await db.close();
      });

      test('changes during onVersionChanged', () async {
        var db = await factory.openDatabase(dbPath, version: 1,
            onVersionChanged: (db, _, __) async {
          await store.record(1).put(db, 'test');
        });
        await store.record(2).put(db, 'other');

        try {
          expect(await store.record(1).get(db), 'test');
          expect(db.version, 1);
          await reOpen(db);
          expect(await store.record(1).get(db), 'test');
          expect(await store.record(2).get(db), 'other');
          expect(db.version, 1);
        } finally {
          await db?.close();
        }
      });

      test('txn during onVersionChanged', () async {
        var db = await factory.openDatabase(dbPath, version: 1,
            onVersionChanged: (db, _, __) async {
          await db.transaction((txn) async {
            await store.record(1).put(txn, 'test');
          });
        });
        await store.record(2).put(db, 'other');

        try {
          expect(await store.record(1).get(db), 'test');
          expect(db.version, 1);
          await reOpen(db);
          expect(await store.record(1).get(db), 'test');
          expect(await store.record(2).get(db), 'other');
          expect(db.version, 1);
        } finally {
          await db?.close();
        }

        db = await factory.openDatabase(dbPath, version: 2,
            onVersionChanged: (db, oldVersion, __) async {
          if (oldVersion == 1) {
            await db.transaction((txn) async {
              expect(await store.record(1).get(txn), 'test');
              await store.record(1).put(txn, 'test2');
            });
          }
        });
        await store.record(2).put(db, 'other2');

        try {
          expect(await store.record(1).get(db), 'test2');
          expect(await store.record(2).get(db), 'other2');
          expect(db.version, 2);
          await reOpen(db);
          expect(await store.record(1).get(db), 'test2');
          expect(await store.record(2).get(db), 'other2');
          expect(db.version, 2);
        } finally {
          await db?.close();
        }
      });

      test('throw during first onVersionChanged', () async {
        try {
          await factory.openDatabase(dbPath, version: 1,
              onVersionChanged: (db, _, __) async {
            throw TestException();
          });
        } on TestException catch (_) {}
        if (hasStorage(factory)) {
          expect(await getExistingDatabaseVersion(factory, dbPath), 0);
        }
      });

      test('throw during second onVersionChanged', () async {
        await (await factory.openDatabase(dbPath)).close();
        if (hasStorage(factory)) {
          try {
            await factory.openDatabase(dbPath, version: 2,
                onVersionChanged: (db, _, __) async {
              throw TestException();
            });
          } on TestException catch (_) {}
          expect(await getExistingDatabaseVersion(factory, dbPath), 1);
        }
      });
    });
  });
}
