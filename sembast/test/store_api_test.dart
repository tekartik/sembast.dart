import 'test_common.dart';

final storeFactory = intMapStoreFactory;
final otherStoreFactory = stringMapStoreFactory;
final testStore = storeFactory.store('test');
final otherStore = StoreRef<String, Map<String, dynamic>>('other');
final keyValueStore = StoreRef<String, String>('keyValue');

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('store_api', () {
    Database db;

    tearDown(() async {
      await db?.close();
      db = null;
    });

    setUp(() async {
      db = await setupForTest(ctx, 'store_api.db');
    });

    test('public', () {
      // What we want public
      // ignore: unnecessary_statements
      StoreRef;
      // ignore: unnecessary_statements
      RecordRef;
      // ignore: unnecessary_statements
      Database;
      // ignore: unnecessary_statements
      Transaction;
      // ignore: unnecessary_statements
      RecordSnapshot;
      // ignore: unnecessary_statements
      RecordsRef;
      // ignore: unnecessary_statements
      intMapStoreFactory;
      // ignore: unnecessary_statements
      stringMapStoreFactory;
      // ignore: unnecessary_statements
      SortOrder;
      // ignore: unnecessary_statements
      Finder;
      // ignore: unnecessary_statements
      Filter;
      // ignore: unnecessary_statements
      Boundary;
      // ignore: unnecessary_statements
      SembastCodec;
      // ignore: unnecessary_statements
      QueryRef;
      // ignore: unnecessary_statements
      FieldValue;
      // ignore: unnecessary_statements
      FieldKey;
      // ignore: unnecessary_statements
      Field;
    });

    test('null_store', () {
      try {
        StoreRef(null);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('key', () {
      var store = StoreRef.main();
      try {
        store.record(null);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('put/get/find string', () async {
      var record = keyValueStore.record('foo');
      await record.put(db, 'bar');

      var snapshot = await record.getSnapshot(db);

      expect(snapshot.ref.store.name, 'keyValue');
      expect(snapshot.ref.key, 'foo');
      expect(snapshot.value, 'bar');

      await record.put(db, 'new', merge: true);
      snapshot = await record.getSnapshot(db);
      expect(snapshot.value, 'new');

      await record.delete(db);
      expect(await record.get(db), isNull);
    });

    test('put/get/find', () async {
      Future _test(DatabaseClient client) async {
        var record = testStore.record(1);

        await record.put(client, {'value': 2});

        var snapshot = await testStore.record(1).getSnapshot(client);

        expect(snapshot.ref.store.name, 'test');
        expect(snapshot.ref.key, 1);
        expect(snapshot.value, <String, dynamic>{'value': 2});

        await record.put(client, {'other': 4}, merge: true);
        snapshot = await record.getSnapshot(client);
        expect(snapshot.value, <String, dynamic>{'value': 2, 'other': 4});

        try {
          snapshot.value['value'] = 3;
          fail('should fail $client');
        } on StateError catch (_) {}

        snapshot = await testStore.findFirst(client);
        expect(snapshot.value, {'value': 2, 'other': 4});
        expect(await testStore.findKey(client), snapshot.key);
        expect(await testStore.findKeys(client), [snapshot.key]);

        try {
          snapshot.value['value'] = 3;
          fail('should fail $client');
        } on StateError catch (_) {}

        var map = Map<String, dynamic>.from(snapshot.value);
        map['value'] = 3;
        await record.put(client, map);
        snapshot = await record.getSnapshot(client);
        expect(snapshot.value, <String, dynamic>{'value': 3, 'other': 4});

        await record.delete(client);
        expect(await record.get(client), isNull);
      }

      await _test(db);
      await db.transaction((txn) async {
        await _test(txn);
      });
    });

    test('updateRecords', () async {
      var store = intMapStoreFactory.store('animals');
      // Store some objects
      int key1, key2, key3;
      await db.transaction((txn) async {
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

      // Update within transaction (not necessary, update is already done in
      // a transaction
      await db.transaction((txn) async {
        expect(await store.update(txn, {'age': 5}, finder: finder), 2);
      });
      expect(await store.records([key1, key2, key3]).get(db), [
        {'name': 'fish', 'age': 5},
        {'name': 'cat'},
        {'name': 'dog', 'age': 5}
      ]);

      expect(
          await store.delete(db,
              finder: Finder(filter: Filter.equals('age', 5))),
          2);
      expect(await store.records([key1, key2, key3]).get(db), [
        null,
        {'name': 'cat'},
        null
      ]);
    });
  });
}
