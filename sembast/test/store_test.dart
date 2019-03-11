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

    test('null', () {
      try {
        StoreRef(null);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });
    test('clear', () async {
      StoreRef store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, "hi");
      await store.clear(db);
      expect(await record.get(db), isNull);
    });

    test('delete', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef("test").delete(db);
      expect(db.storeNames, ['_main']);
    });

    test('delete_main', () async {
      expect(db.storeNames, ['_main']);
      await StoreRef.main().delete(db);
      expect(db.storeNames, ['_main']);
    });

    test('put/delete_store', () async {
      var store = StoreRef('test');
      RecordRef record = store.record(1);
      await record.put(db, 'test');
      expect(db.storeNames, contains('test'));
      await store.delete(db);
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
  });
}
