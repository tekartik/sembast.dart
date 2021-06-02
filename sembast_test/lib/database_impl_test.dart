library sembast.database_impl_test;

// basically same as the io runner but with extra output
import 'package:path/path.dart';
// ignore: implementation_imports
import 'package:sembast/src/database_impl.dart' show SembastDatabase;

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  final factory = ctx.factory;

  group('database_impl', () {
    group('cooperator', () {
      test('disable', () async {
        var dbPath1 = dbPathFromName(join('database_impl_1.db'));
        var dbPath2 = dbPathFromName(join('database_impl_2.db'));
        var dbPath3 = dbPathFromName(join('database_impl_3.db'));
        await factory.deleteDatabase(dbPath1);
        await factory.deleteDatabase(dbPath2);
        await factory.deleteDatabase(dbPath3);

        var db = (await factory.openDatabase(dbPath1)) as SembastDatabase;
        expect(db.cooperator, isNotNull);
        await db.close();

        disableSembastCooperator();

        db = (await factory.openDatabase(dbPath2)) as SembastDatabase;
        expect(db.cooperator, isNull);
        await db.close();

        enableSembastCooperator();
        db = (await factory.openDatabase(dbPath3)) as SembastDatabase;
        expect(db.cooperator, isNotNull);
        await db.close();
      });
    });
  });
}
