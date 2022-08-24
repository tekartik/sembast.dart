library sembast.store_test;

import 'dart:async';

import 'test_common.dart';

final storeFactory = intMapStoreFactory;
final otherStoreFactory = stringMapStoreFactory;
final testStore = storeFactory.store('test');
final otherStore = StoreRef<String, Map<String, Object?>>('other');
final keyValueStore = StoreRef<String, String>('keyValue');

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('store', () {
    late Database db;

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
      await record.put(db, 'hi');
      await store.delete(db);
      expect(await record.get(db), isNull);
    });

    test('put/get', () async {
      var store1 = StoreRef<int, Object?>('test1');
      var store2 = StoreRef<int, Object?>('test2');
      expect(await store1.record(1).put(db, 'hi'), 'hi');
      expect(await store2.record(1).put(db, 'ho'), 'ho');
      expect(await store1.record(1).get(db), 'hi');
      expect(await store2.record(1).get(db), 'ho');
      expect(await store1.record(2).put(db, true), true);
      db = await reOpen(db);
      expect(await store1.record(1).get(db), 'hi');
      expect(await store1.record(2).get(db), true);
      expect(await store2.record(1).get(db), 'ho');
    });

    test('bool', () async {
      var store = StoreRef<int, bool>('bool');
      var record = store.record(1);
      await record.put(db, true);
      expect(await record.get(db), isTrue);
      await record.put(db, false);
      expect(await record.get(db), isFalse);
      // await record.put(db, null); - no longer supported
      // expect(await record.get(db), isNull);
      expect((await record.getSnapshot(db))!.value, isFalse);
    });

    test('records', () async {
      var store = StoreRef('test');
      final records = store.records([1, 2]);
      expect((await records.getSnapshots(db)), [null, null]);
      expect((await records.get(db)), [null, null]);
      await store.record(2).put(db, 'hi');
      expect((await records.get(db)), [null, 'hi']);
      expect((await records.getSnapshots(db)).last!.value, 'hi');
    });

    test('update', () async {
      final store = intMapStoreFactory.store('animals');
      // Store some objects
      late int key1, key2, key3;
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
      var store = intMapStoreFactory.store('test');
      var record = store.record(1);
      await record.put(db, {
        'test': {'sub': 1}
      });
      var snapshot = (await store.findFirst(db))!;
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

    test('order', () async {
      var store = StoreRef<int, String>.main();
      var record1 = store.record(1);
      var record2 = store.record(2);
      var record3 = store.record(3);
      var record4 = store.record(4);
      var record5 = store.record(5);
      await record3.put(db, ''); // nnbd: null no longer supported
      await record2.put(db, '');
      expect(await store.findKeys(db), [2, 3]);
      await record4.put(db, '');
      expect(await store.findKeys(db), [2, 3, 4]);
      await db.transaction((txn) async {
        await record1.put(txn, '');
        await record5.put(txn, '');
        expect(await store.findKeys(txn), [1, 2, 3, 4, 5]);
      });
      expect(await store.findKeys(db), [1, 2, 3, 4, 5]);
    });
    group('value_int', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, int>.main();
        var key = await store.add(db, 1);
        var record = store.record(key);
        expect(await record.get(db), 1);
        expect((await store.findFirst(db))!.value, 1);
      });

      test('addAll', () async {
        // this is ok too
        final store = StoreRef<String, int>.main();
        var keys = await store.addAll(db, [1, 2]);
        expect(keys, hasLength(2));
        var record = store.record(keys.first);
        expect(await record.get(db), 1);
        expect((await store.findFirst(db))!.value, 1);
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
        expect((await store.findFirst(db))!.value, 1);
        expect(await store.record(keys[1]).get(db), 2);
      });
    });

    group('value_map', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, Map<String, Object?>>.main();
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
        final store = StoreRef<String, Map<String, Object?>>.main();
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
        final store = StoreRef<String, Map<String, Object?>>.main();
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
        expect((await store.findFirst(db))!.value, true);
      });
    });

    group('value_string', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, String>.main();
        var key = await store.add(db, 'test');
        var record = store.record(key);
        expect(await record.get(db), 'test');
        expect((await store.findFirst(db))!.value, 'test');
      });
    });

    group('value_double', () {
      test('add', () async {
        // this is ok too
        final store = StoreRef<String, double>.main();
        var key = await store.add(db, 1);
        var record = store.record(key);
        expect(await record.get(db), 1);

        var value = (await store.findFirst(db))!.value;
        expect(value, 1);
        if (!isJavascriptVm) {
          expect(value.runtimeType, double);
        }
        await db.close();
        db = await ctx.factory.openDatabase(db.path);
        value = (await store.findFirst(db))!.value;
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

        expect((await store.findFirst(db))!.value, 0.1);
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
        final store = StoreRef<String, Map<Object?, Object?>>.main();
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
        final list = await record.get(db);
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

    test('drop', () async {
      final store = StoreRef<int, String>('store');
      var key = await store.add(db, 'test');
      var record = store.record(key);
      expect(await record.get(db), 'test');
      await store.drop(db);
      await db.close();
      db = await ctx.factory.openDatabase(db.path);
      expect(await record.get(db), isNull);
    });

    group('store_api', () {
      Database? db;

      tearDown(() async {
        await db?.close();
        db = null;
      });

      setUp(() async {
        db = await setupForTest(ctx, 'store_api.db');
      });

      test('put/get/find string', () async {
        var record = keyValueStore.record('foo');
        await record.put(db!, 'bar');

        var snapshot = (await record.getSnapshot(db!))!;

        expect(snapshot.ref.store.name, 'keyValue');
        expect(snapshot.ref.key, 'foo');
        expect(snapshot.value, 'bar');

        await record.put(db!, 'new', merge: true);
        snapshot = (await record.getSnapshot(db!))!;
        expect(snapshot.value, 'new');

        await record.delete(db!);
        expect(await record.get(db!), isNull);
      });

      test('put/get/find', () async {
        Future testClient(DatabaseClient client) async {
          var record = testStore.record(1);

          await record.put(client, {'value': 2});

          var snapshot = (await testStore.record(1).getSnapshot(client))!;

          expect(snapshot.ref.store.name, 'test');
          expect(snapshot.ref.key, 1);
          expect(snapshot.value, <String, Object?>{'value': 2});

          await record.put(client, {'other': 4}, merge: true);
          snapshot = (await record.getSnapshot(client))!;
          expect(snapshot.value, <String, Object?>{'value': 2, 'other': 4});

          try {
            snapshot.value['value'] = 3;
            fail('should fail $client');
          } on StateError catch (_) {}

          snapshot = (await testStore.findFirst(client))!;
          expect(snapshot.value, {'value': 2, 'other': 4});
          expect(await testStore.findKey(client), snapshot.key);
          expect(await testStore.findKeys(client), [snapshot.key]);

          try {
            snapshot.value['value'] = 3;
            fail('should fail $client');
          } on StateError catch (_) {}

          var map = Map<String, Object?>.from(snapshot.value);
          map['value'] = 3;
          await record.put(client, map);
          snapshot = (await record.getSnapshot(client))!;
          expect(snapshot.value, <String, Object?>{'value': 3, 'other': 4});

          await record.delete(client);
          expect(await record.get(client), isNull);
        }

        await testClient(db!);
        await db!.transaction((txn) async {
          await testClient(txn);
        });
      });

      test('updateRecords', () async {
        final store = intMapStoreFactory.store('animals');
        // Store some objects
        late int key1, key2, key3;
        await db!.transaction((txn) async {
          key1 = await store.add(txn, {'name': 'fish'});
          key2 = await store.add(txn, {'name': 'cat'});
          key3 = await store.add(txn, {'name': 'dog'});
        });

        // Filter for updating records
        var finder = Finder(filter: Filter.greaterThan('name', 'cat'));

        // Update without transaction
        await store.update(db!, {'age': 4}, finder: finder);
        expect(await store.records([key1, key2, key3]).get(db!), [
          {'name': 'fish', 'age': 4},
          {'name': 'cat'},
          {'name': 'dog', 'age': 4}
        ]);

        // Update within transaction (not necessary, update is already done in
        // a transaction
        await db!.transaction((txn) async {
          expect(await store.update(txn, {'age': 5}, finder: finder), 2);
        });
        expect(await store.records([key1, key2, key3]).get(db!), [
          {'name': 'fish', 'age': 5},
          {'name': 'cat'},
          {'name': 'dog', 'age': 5}
        ]);

        expect(
            await store.delete(db!,
                finder: Finder(filter: Filter.equals('age', 5))),
            2);
        expect(await store.records([key1, key2, key3]).get(db!), [
          null,
          {'name': 'cat'},
          null
        ]);
      });
    });
    test('onCount', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
      var completer = Completer();

      var sub = store.onCount(db).listen((count) {
        if (index == 0) {
          expect(count, 0);
        } else if (index == 1) {
          expect(count, 1);
        } else if (index == 2) {
          expect(count, 2);
        } else if (index == 3) {
          expect(count, 1);
        }
        if (++index == 4) {
          completer.complete();
        }
      });
      //await Future.delayed(Duration(milliseconds: 1));
      // create
      await record.put(db, 'test');

      // add
      await store.record(2).put(db, 'test3');
      expect(await store.count(db), 2);

      // update
      await record.put(db, 'test2');

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 4);
    });

    test('onCount with filter', () async {
      var store = StoreRef<int, String>.main();
      var record = store.record(1);
      var index = 0;
      var completer = Completer();

      // When starting listening the record does not exists yet
      var filter = Filter.greaterThan(Field.value, 'test');
      expect(await store.count(db, filter: filter), 0);

      var sub = store.onCount(db, filter: filter).listen((snapshots) {
        if (index == 0) {
          expect(snapshots, 0);
        } else if (index == 1) {
          expect(snapshots, 1);
        } else if (index == 2) {
          expect(snapshots, 2);
        } else if (index == 3) {
          expect(snapshots, 1);
        }
        if (++index == 4) {
          completer.complete();
        }
      });
      //await Future.delayed(Duration(milliseconds: 1));
      // create
      await record.put(db, 'test2');
      // add
      await store.record(2).put(db, 'test1');
      expect(await store.count(db, filter: filter), 2);

      // update
      await record.put(db, 'test1');

      // change that does not affect the query
      await store.record(3).put(db, 'dummy not in query');

      // delete
      await record.delete(db);
      await completer.future;
      await sub.cancel();
      expect(index, 4);
    });
  });
}
