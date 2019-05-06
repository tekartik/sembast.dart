library sembast.store_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('store', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('clear', () async {
      final store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, "hi");
      await store.delete(db);
      expect(await record.get(db), isNull);
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

    test('put/get', () async {
      var store1 = StoreRef<int, dynamic>('test1');
      var store2 = StoreRef<int, dynamic>("test2");
      expect(await store1.record(1).put(db, "hi"), 1);
      expect(await store2.record(1).put(db, "ho"), 1);
      expect(await store1.record(1).get(db), "hi");
      expect(await store2.record(1).get(db), "ho");
      expect(await store1.record(2).put(db, true), 2);
      db = await reOpen(db);
      expect(await store1.record(1).get(db), "hi");
      expect(await store1.record(2).get(db), true);
      expect(await store2.record(1).get(db), "ho");
    });

    test('bool', () async {
      var store = StoreRef<int, bool>('bool');
      var record = store.record(1);
      await record.put(db, true);
      expect(await record.get(db), isTrue);
      await record.put(db, false);
      expect(await record.get(db), isFalse);
      await record.put(db, null);
      expect(await record.get(db), isNull);
      expect((await record.getSnapshot(db)).value, isNull);
    });

    test('records', () async {
      var store = StoreRef("test");
      RecordsRef records = store.records([1, 2]);
      expect((await records.getSnapshots(db)), [null, null]);
      expect((await records.get(db)), [null, null]);
      await store.record(2).put(db, "hi");
      expect((await records.get(db)), [null, "hi"]);
      expect((await records.getSnapshots(db)).last.value, 'hi');
    });

    test('read_only', () async {
      var store = intMapStoreFactory.store("test");
      var record = store.record(1);
      await record.put(db, {
        'test': {'sub': 1}
      });
      var snapshot = await store.findFirst(db);
      expect(snapshot.value, {
        'test': {'sub': 1}
      });
      try {
        (snapshot.value['test'] as Map)['sub'] = 2;
        fail('should fail');
      } on StateError catch (_) {}

      try {
        (Map.from(snapshot.value)['test'] as Map)['sub'] = 2;

        fail('should fail');
      } on StateError catch (_) {}

      expect(snapshot.value, {
        'test': {'sub': 1}
      });
    });

    group('value_int', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, int>.main();
        var key = await store.add(db, 1);
        var record = store.record(key);
        expect(await record.get(db), 1);
        expect((await store.findFirst(db)).value, 1);
      });
    });

    group('value_bool', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, bool>.main();
        var key = await store.add(db, true);
        var record = store.record(key);
        expect(await record.get(db), true);
        expect((await store.findFirst(db)).value, true);
      });
    });

    group('value_string', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, String>.main();
        var key = await store.add(db, 'test');
        var record = store.record(key);
        expect(await record.get(db), 'test');
        expect((await store.findFirst(db)).value, 'test');
      });
    });

    group('value_double', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, double>.main();
        var key = await store.add(db, 0.1);
        var record = store.record(key);
        expect(await record.get(db), 0.1);
        expect((await store.findFirst(db)).value, 0.1);
      });
    });

    group('value_num', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, num>.main();
        var key = await store.add(db, 0.1);
        var record = store.record(key);
        expect(await record.get(db), 0.1);

        var key2 = await store.add(db, 1);
        var record2 = store.record(key2);
        expect(await record2.get(db), 1);

        expect((await store.findFirst(db)).value, 0.1);
      });
    });

    group('map_string_string', () {
      test('add', () async {
        final store = StoreRef<String, Map<String, String>>.main();
        try {
          await store.add(db, {'test': 'value'});
          fail('should fail');
        } on ArgumentError catch (_) {}

        try {
          await store.update(db, {'test': 'value'});
          fail('should fail');
        } on ArgumentError catch (_) {}

        var record = store.record('1');
        try {
          await record.put(db, {'test': 'value'});
          fail('should fail');
        } on ArgumentError catch (_) {}

        try {
          await record.update(db, {'test': 'value'});
          fail('should fail');
        } on ArgumentError catch (_) {}
      });
    });

    group('map_dynamic_dynamic', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, Map<dynamic, dynamic>>.main();
        var key = await store.add(db, {'test': 'value'});
        var record = store.record(key);

        await record.get(db);
      });
    });

    group('list', () {
      test('add', () async {
        final store = StoreRef<int, List>.main();
        var key = await store.add(db, [1]);
        var record = store.record(key);
        List list = await record.get(db);
        expect(list, [1]);
      });
    });

    group('list_string', () {
      test('add', () async {
        final store = StoreRef<int, List<String>>.main();
        try {
          await store.add(db, ['1']);
          fail('should fail');
        } on ArgumentError catch (_) {}
      });
    });
  });
}
