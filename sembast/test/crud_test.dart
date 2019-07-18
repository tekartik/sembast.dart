library sembast.crud_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/v2/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('crud', () {
    Database db;

    final mainStore = StoreRef.main();

    setUp(() async {
      db = await setupForTest(ctx, 'crud.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put', () async {
      final store = StoreRef<int, String>.main();
      expect(await store.record(1).put(db, "hi"), 'hi');
    });

    test('update', () async {
      final store = StoreRef<int, String>.main();
      var record = store.record(1);
      expect(await record.update(db, 'hi'), isNull);
      await record.put(db, 'hi');
      expect(await record.update(db, 'ho'), 'ho');
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
      expect(
          await record.put(db, {'test': FieldValue.delete, 'a.b.c': 4},
              merge: true),
          {
            'a': {
              'b': {'c': 3}
            },
            'a.b.c': 4
          });
    });

    test('add_with_dot', () async {
      final store = intMapStoreFactory.store();
      // var record = store.record(1);
      int key = await store.add(db, {'foo.bar': 1});
      var record = store.record(key);
      expect(await record.get(db), {'foo.bar': 1});
    });

    test('put_with_dot', () async {
      final store = intMapStoreFactory.store();
      var record = store.record(1);
      await record.put(db, {'foo.bar': 1});
      expect(await record.get(db), {'foo.bar': 1});
      await record.put(db, {'foo.bar': 2});
      expect(await record.get(db), {'foo.bar': 2});
      await record.put(db, {'foo.bar': 3}, merge: true);
      expect(await record.get(db), {'foo.bar': 3});
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
      var readValue = await record.get(db);
      expect(readValue, "hi");
      // immutable value are not clones
      expect(identical(value, readValue), isTrue);
      expect(await mainStore.count(db), 1);
    });

    test('readOnly', () async {
      final store = intMapStoreFactory.store();
      var record = store.record(1);
      await record.put(db, {'test': 1});
      var snapshot = await record.getSnapshot(db);
      try {
        snapshot.value['test'] = 2;
        fail('should fail');
      } on StateError catch (_) {}
    });

    test('put_update', () async {
      var record = mainStore.record(1);
      await record.put(db, "hi");
      await record.put(db, "ho");
      expect((await record.get(db)), "ho");
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
      var infoRead = await record.get(db);
      expect(infoRead, info);
      expect(identical(infoRead, info), isFalse);
    });
  });
}
