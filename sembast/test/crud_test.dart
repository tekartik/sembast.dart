library sembast.crud_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('crud', () {
    Database db;

    final mainStore = StoreRef.main();

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('put', () async {
      final store = StoreRef<int, String>.main();
      expect(await store.record(1).put(db, "hi"), 1);
    });

    test('update', () async {
      final store = StoreRef<int, String>.main();
      expect(await store.record(1).update(db, 'hi'), isNull);
      await db.put('hi', 1);
      expect(await db.update('ho', 1), 'ho');
    });

    test('update_map', () async {
      final store = intMapStoreFactory.store();
      var key = await store.add(db, {"test": 1});
      expect(key, 1);
      var record = store.record(key);
      expect(await record.update(db, {'new': 2}), {'test': 1, 'new': 2});
      expect(await record.update(db, {'new': FieldValue.delete, 'a.b.c': 3}), {
        'test': 1,
        'a': {
          'b': {'c': 3}
        }
      });
    });
    test('put_nokey', () async {
      var key = await mainStore.add(db, "hi");
      expect(key, 1);
      var key2 = await mainStore.add(db, "hi");
      expect(key2, 2);
    });

    test('get none', () async {
      expect(await mainStore.record(1).get(db), isNull);
    });

    test('put_get', () async {
      String value = "hi";
      var record = mainStore.record(1);
      await record.put(db, value);
      var readValue = await record.getValue(db);
      expect(readValue, "hi");
      // immutable value are not clones
      expect(identical(value, readValue), isTrue);
      expect(await mainStore.count(db), 1);
    });

    test('put_update', () async {
      var record = mainStore.record(1);
      await record.put(db, "hi");
      await record.put(db, "ho");
      expect((await record.get(db)).value, "ho");
      expect(await mainStore.count(db), 1);
    });

    test('put_delete', () async {
      var record = mainStore.record(1);
      await record.put(db, "hi");
      expect(await record.delete(db), 1);
      expect(await record.get(db), isNull);
      expect(await mainStore.count(db), 0);
    });

    test('auto_increment put_get_map', () async {
      Map info = {"info": 12};
      var key = await mainStore.add(db, info);
      var record = mainStore.record(key);
      var infoRead = (await record.get(db)).value;
      expect(infoRead, info);
      expect(identical(infoRead, info), isFalse);
    });
  });
}
