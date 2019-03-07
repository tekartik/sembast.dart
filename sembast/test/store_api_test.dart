import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_store.dart';

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
  test('factory', () async {
    var snapshot = storeFactory
        .store('test')
        .record(1)
        .snapshot(<String, dynamic>{'test': 1});
    expect(snapshot.ref.store.name, 'test');
    expect(snapshot.ref.key, 1);
    expect(snapshot.value, <String, dynamic>{'test': 1});
  });

  group('find', () {
    Database db;

    tearDown(() async {
      await db?.close();
      db = null;
    });

    setUp(() async {
      db = await setupForTest(ctx);
    });

    test('put/get/find string', () async {
      var record = keyValueStore.record('foo');
      await record.put(db, 'bar');

      var snapshot = await record.get(db);

      expect(snapshot.ref.store.name, 'keyValue');
      expect(snapshot.ref.key, 'foo');
      expect(snapshot.value, 'bar');

      await record.put(db, 'new', merge: true);
      snapshot = await record.get(db);
      expect(snapshot.value, 'new');

      await record.delete(db);
      expect(await record.get(db), isNull);
    });

    test('put/get/find', () async {
      Future _test(DatabaseClient client) async {
        var record = testStore.record(1);

        await record.put(client, {'value': 2});

        var snapshot = await testStore.record(1).get(client);

        expect(snapshot.ref.store.name, 'test');
        expect(snapshot.ref.key, 1);
        expect(snapshot.value, <String, dynamic>{'value': 2});

        await record.put(client, {'other': 4}, merge: true);
        snapshot = await record.get(client);
        expect(snapshot.value, <String, dynamic>{'value': 2, 'other': 4});

        try {
          snapshot.value['value'] = 3;
          fail('should fail $client');
        } on StateError catch (_) {}

        snapshot = await testStore.find(client, Finder());
        expect(snapshot.value, {'value': 2, 'other': 4});

        try {
          snapshot.value['value'] = 3;
          fail('should fail $client');
        } on StateError catch (_) {}

        var map = Map<String, dynamic>.from(snapshot.value);
        map['value'] = 3;
        await record.put(client, map);
        snapshot = await record.get(client);
        expect(snapshot.value, <String, dynamic>{'value': 3, 'other': 4});

        await record.delete(client);
        expect(await record.get(client), isNull);
      }

      await _test(db);
      await db.transaction((txn) async {
        await _test(txn);
      });
    });
  });
}
