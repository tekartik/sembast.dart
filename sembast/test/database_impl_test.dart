library sembast.database_test;

import 'package:sembast/src/api/protected/database.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  final factory = ctx.factory as DatabaseFactoryMixin;
  String dbPath;

  group('database_impl', () {
    dbPath = dbPathFromName('compat/database_impl.db');

    group('open', () {
      Database? db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        // ignore: dead_code
        return db?.close();
      });

      test('open_then_open_no_version', () async {
        final db =
            await factory.openDatabase(dbPath, version: 1) as SembastDatabase;
        return db.reOpen().then((Database db) {
          expect(db.path, dbPath);
          expect(db.version, 1);
          return db.close();
        });
      });
    });

    group('onVersionChanged', () {
      Database? db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        // ignore: dead_code
        return db?.close();
      });

      test('open_then_open_no_version_or_same_version', () async {
        final db =
            await factory.openDatabase(dbPath, version: 1) as SembastDatabase;
        void onVersionChanged(Database db, int oldVersion, int newVersion) {
          fail('not changed');
        }

        return db
            .reOpen(DatabaseOpenOptions(onVersionChanged: onVersionChanged))
            .then((Database db) {
          expect(db.path, dbPath);
          expect(db.version, 1);
          return db.close();
        }).then((_) {
          return db
              .reOpen(DatabaseOpenOptions(
                  version: 1, onVersionChanged: onVersionChanged))
              .then((Database db) {
            expect(db.path, dbPath);
            expect(db.version, 1);
            return db.close();
          });
        });
      });

      test('open_then_open_new_version', () async {
        final db =
            await factory.openDatabase(dbPath, version: 1) as SembastDatabase;
// save to make sure we've been through
        int? localOldVersion;
        int? localNewVersion;
        void onVersionChanged(Database db, int oldVersion, int newVersion) {
          expect(db.version, oldVersion);
          localOldVersion = oldVersion;
          localNewVersion = newVersion;
        }

        return db
            .reOpen(DatabaseOpenOptions(
                version: 2, onVersionChanged: onVersionChanged))
            .then((Database db) {
          expect(localOldVersion, 1);
          expect(localNewVersion, 2);
          expect(db.path, dbPath);
          expect(db.version, 2);
          return db.close();
        });
      });
    });

    group('format', () {
      SembastDatabase? db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        return db?.close();
      });

      test('export', () async {
        db = await factory.openDatabase(dbPath) as SembastDatabase;
        expect(
            // ignore: deprecated_member_use
            db!.toJson()['exportStat'],
            // ignore: deprecated_member_use, deprecated_member_use_from_same_package
            factory.hasStorage ? isNotNull : isNull);
      });
    });

    group('openHelper', () {
      SembastDatabase? db;

      setUp(() {
        return factory.deleteDatabase(dbPath).then((_) {});
      });

      tearDown(() {
        return db?.close();
      });

      test('export', () async {
        db = await factory.openDatabase(dbPath) as SembastDatabase;
        expect(factory.getExistingDatabaseOpenHelper(dbPath), isNotNull);
        await db?.close();
        expect(factory.getExistingDatabaseOpenHelper(dbPath), isNull);
      });
    });
  });
}
