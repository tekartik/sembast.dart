library sembast.store_test;

import 'package:sembast/src/database_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('src_store', () {
    SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'src_store.db') as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    test('delete', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef("test").drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('delete_main', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef.main().drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('put/delete_store', () async {
      var store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, 'test');
      expect(db.storeNames, contains('test'));
      await store.drop(db);
      expect(db.storeNames, isNot(contains('test')));
      expect(await record.get(db), isNull);
    });
  });
}
