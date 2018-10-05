library sembast.database_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  DatabaseFactory factory = ctx.factory;
  String dbPath;

  group('database', () {
    dbPath = ctx.dbPath;

    group('open', () {
      Database db;

      setUp(() async {
        await factory.deleteDatabase(dbPath);
      });

      tearDown(() {
        if (db != null) {
          db.close();
        }
      });

      test('open_no_version', () {
        return factory.openDatabase(dbPath).then((Database db) {
          expect(db.version, 1);
          expect(db.path, dbPath);
          db.close();
        });
      });

      test('open_existing_no_version', () {
        return factory
            .openDatabase(dbPath, mode: DatabaseMode.existing)
            .then((Database db) {
          fail("should fail");
        }).catchError((e) {
          expect((e as DatabaseException).code,
              DatabaseException.errDatabaseNotFound);
        });
      });

      test('open_version', () {
        return factory.openDatabase(dbPath, version: 1).then((Database db) {
          expect(db.version, 1);
          expect(db.path, dbPath);
          db.close();
        });
      });

      test('open_twice_no_close', () {
        return factory.openDatabase(dbPath, version: 1).then((Database db) {
          expect(db.version, 1);
          expect(db.path, dbPath);
          return factory.openDatabase(dbPath, version: 1).then((Database db2) {
            // behavior is unexpected from now...
            expect(db.version, 1);
            expect(db.path, dbPath);
            db2.close();
          });
        });
      });
    });

    group('onVersionChanged', () {
      Database db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        if (db != null) {
          db.close();
        }
      });

      test('open_no_version', () {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        return factory
            .openDatabase(dbPath, onVersionChanged: _onVersionChanged)
            .then((Database db) {
          expect(_oldVersion, 0);
          expect(_newVersion, 1);
          expect(db.version, 1);
          expect(db.path, dbPath);
          db.close();
        });
      });

      test('open_version', () {
        // save to make sure we've been through
        int _oldVersion;
        int _newVersion;
        _onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          _oldVersion = oldVersion;
          _newVersion = newVersion;
        }

        return factory
            .openDatabase(dbPath,
                version: 1, onVersionChanged: _onVersionChanged)
            .then((Database db) {
          expect(_oldVersion, 0);
          expect(_newVersion, 1);
          expect(db.version, 1);
          expect(db.path, dbPath);
          db.close();
        });
      });

      test('changes during onVersionChanged', () async {
        var db = await factory.openDatabase(dbPath, version: 1,
            onVersionChanged: (db, _, __) async {
          await db.put('test', 1);
        });
        await db.put('other', 2);

        try {
          expect(await db.get(1), 'test');
          expect(db.version, 1);
          await reOpen(db);
          expect(await db.get(1), 'test');
          expect(db.version, 1);
        } finally {
          await db?.close();
        }
      });
    });
  });
}
