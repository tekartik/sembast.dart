import 'package:sembast/sembast_store.dart';

import 'test_common.dart';

final storeFactory = intMapStoreFactory;
final otherStoreFactory = stringMapStoreFactory;
final testStore = storeFactory.store('test');
final otherStore = StoreRef<String, Map<String, dynamic>>('other');

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

    test('put/get/find', () async {
      var snapshot = storeFactory
          .store('test')
          .record(1)
          .snapshot(<String, dynamic>{'test': 1});
      expect(snapshot.ref.store.name, 'test');
      expect(snapshot.ref.key, 1);
      expect(snapshot.value, <String, dynamic>{'test': 1});

      var record = testStore.record(1);
      await record.put(db, {'value': 2});
      /*
      snapshot = await testStore.record(1).get(db);

      expect(snapshot.ref.store.name, 'test');
      expect(snapshot.ref.key, 1);
      expect(snapshot.value, <String, dynamic>{'value': 2});
      snapshot.value['value'] = 2;
      */

      await record.delete(db);
      expect(await record.get(db), isNull);
    });
  });
}
