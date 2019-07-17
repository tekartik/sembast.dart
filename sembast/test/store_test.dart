library sembast.store_test;

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('store', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'store.db');
    });

    tearDown(() {
      return db.close();
    });

    test('equals', () {
      var store1 = StoreRef.main();
      var store2 = StoreRef.main();
      expect(store1, store2);
      expect(store1.hashCode, store2.hashCode);
      expect(store1, isNot(StoreRef('test')));
      expect(StoreRef('test'), StoreRef('test'));
    });

    test('clear', () async {
      final store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, "hi");
      await store.delete(db);
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

    test('update', () async {
      var store = intMapStoreFactory.store('animals');
      // Store some objects
      int key1, key2, key3;
      await db.transaction((txn) async {
        //var store = txn.getStore('animals');
        key1 = await store.add(txn, {'name': 'fish'});
        key2 = await store.add(txn, {'name': 'cat'});
        key3 = await store.add(txn, {'name': 'dog'});
      });

      // Filter for updating records
      var finder = Finder(filter: Filter.greaterThan('name', 'cat'));

      // Update without transaction
      await store.update(db, {'age': 4}, finder: finder);
      expect(await store.records([key1, key2, key3]).get(db), [
        {'name': 'fish', 'age': 4},
        {'name': 'cat'},
        {'name': 'dog', 'age': 4}
      ]);

      // Update within transaction
      await db.transaction((txn) async {
        await store.update(txn, {'age': 5}, finder: finder);
      });
      expect(await store.records([key1, key2, key3]).get(db), [
        {'name': 'fish', 'age': 5},
        {'name': 'cat'},
        {'name': 'dog', 'age': 5}
      ]);
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
      test('addAll', () async {
        // this is ok too
        final store = StoreRef<String, int>.main();
        var keys = await store.addAll(db, [1, 2]);
        expect(keys, hasLength(2));
        var record = store.record(keys.first);
        expect(await record.get(db), 1);
        expect((await store.findFirst(db)).value, 1);
        expect(await store.record(keys[1]).get(db), 2);
      });

      test('addAll_transaction', () async {
        // this is ok too
        final store = StoreRef<String, int>.main();
        var keys = await db.transaction((txn) {
          return store.addAll(txn, [1, 2]);
        });
        expect(keys, hasLength(2));
        var record = store.record(keys.first);
        expect(await record.get(db), 1);
        expect((await store.findFirst(db)).value, 1);
        expect(await store.record(keys[1]).get(db), 2);
      });
    });

    group('value_map', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, Map<String, dynamic>>.main();
        var innerMap = {'sub': 1};
        var map = {'test': innerMap};
        var key = await store.add(db, map);
        var record = store.record(key);
        expect(await record.get(db), {
          'test': {'sub': 1}
        });
        innerMap['sub'] = 2;
        expect(await record.get(db), {
          'test': {'sub': 1}
        });
      });

      test('type', () async {
        final store = StoreRef<String, Map<String, dynamic>>.main();
        var map = {
          'int': 1,
          'double': 0.1,
          'String': 'text',
          'List': [1],
          'Map': {'sub': 1}
        };
        var key = await store.add(db, map);
        var record = store.record(key);
        expect(await record.get(db), {
          'int': 1,
          'double': 0.1,
          'String': 'text',
          'List': [1],
          'Map': {'sub': 1}
        });
      });

      test('datetime', () async {
        final store = StoreRef<String, Map<String, dynamic>>.main();
        var map = {'dateTime': DateTime.now()};
        try {
          await store.add(db, map);
          fail('should have failed');
        } on ArgumentError catch (_) {}
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
        var key = await store.add(db, 1);
        var record = store.record(key);
        expect(await record.get(db), 1);

        double value = (await store.findFirst(db)).value;
        expect(value, 1);
        if (!isJavascriptVm) {
          expect(value.runtimeType, double);
        }
        await db.close();
        db = await ctx.factory.openDatabase(db.path);
        value = (await store.findFirst(db)).value;
        expect(value, 1);
        if (!isJavascriptVm) {
          expect(value.runtimeType, double);
        }
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
