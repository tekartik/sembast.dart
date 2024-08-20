library sembast.test.src_store_test;

import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'test_common.dart';

void main() {
  defineSrcStoreTests(memoryDatabaseContext);
}

void defineSrcStoreTests(DatabaseTestContext ctx) {
  group('src_store', () {
    late SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'src_store.db') as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    test('delete', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef<String, Object>('test').drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('delete_main', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef<String, Object>.main().drop(db);
      expect(db.storeNames, ['_main']);
    });

    test('put/delete_store', () async {
      var store = StoreRef<int, Object>('test');
      var record = store.record(1);
      await record.put(db, 'test');
      expect(db.storeNames, contains('test'));
      await store.drop(db);
      expect(db.storeNames, isNot(contains('test')));
      expect(await record.get(db), isNull);
    });

    test('generateKey(Objet?)', () async {
      var storeDynamic = SembastStoreRef<Object?, Object?>('dynamic_key');
      expect(await storeDynamic.generateKey(db), 1);
      expect(await storeDynamic.generateKey(db), 2);
    });

    test('generateKey(Objet)', () async {
      var storeDynamic = SembastStoreRef<Object, Object?>('dynamic_key');
      expect(await storeDynamic.generateKey(db), 1);
      expect(await storeDynamic.generateKey(db), 2);
    }, skip: 'Why?...');

    test('generateIntKey', () async {
      var storeObject = SembastStoreRef<Object, String>('object_key');
      var key1 = await storeObject.generateIntKey(db);
      var key2 = await storeObject.generateIntKey(db);
      expect(key1, 1);
      expect(key2, 2);
    });
  });
}
