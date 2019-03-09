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
      var store = StoreRef('test');
      var record = store.record(1);
      await record.put(db, "hi");
      await store.clear(db);
      expect(await record.get(db), isNull);
    });

    test('delete', () {
      var store = db.findStore("test");
      expect(store, isNull);
      store = db.getStore("test");
      expect(store, isNotNull);
      store = db.findStore("test");
      expect(store, isNotNull);
      return db.deleteStore("test").then((_) {
        expect(db.findStore("test"), isNull);
      });
    });

    //TODO FROM HERE

    test('delete_main', () async {
      var mainStoreName = db.mainStore.name;
      var store = db.findStore(mainStoreName);
      expect(store, isNotNull);
      expect(db.stores, [db.mainStore]);
      await db.deleteStore(mainStoreName);
      expect(db.stores, [db.mainStore]);
      expect(db.findStore(mainStoreName), isNotNull);
    });

    test('delete_main', () {
      var store = db.getStore(null);
      return db.deleteStore(null).then((_) {
        expect(db.findStore(null), store);
        expect(db.findStore(null), db.mainStore);
        expect(db.stores, [db.mainStore]);
        return db.deleteStore(db.mainStore.name).then((_) {
          expect(db.findStore(null), db.mainStore);
          expect(db.stores, [db.mainStore]);
        });
      });
    });

    test('put/delete_store', () async {
      var store = db.getStore("test_store");
      await store.put('test', 1);
      await db.deleteStore('test_store');
      store = db.getStore("test_store");
      expect(await store.get(1), isNull);
    });

    test('put/get', () {
      var store1 = db.getStore("test1");
      var store2 = db.getStore("test2");
      return store1.put("hi", 1).then((key) {
        expect(key, 1);
      }).then((_) {
        return store2.put("ho", 1).then((key) {
          expect(key, 1);
        });
      }).then((_) {
        return store1.get(1).then((value) {
          expect(value, "hi");
        });
      }).then((_) {
        return store2.get(1).then((value) {
          expect(value, "ho");
        });
      }).then((_) {
        return store1.put(true, 2).then((key) {
          expect(key, 2);
        });
      }).then((_) {
        return store1.get(2).then((value) {
          expect(value, true);
        });
      }).then((_) {
        return store2.put(false, 2).then((key) {
          expect(key, 2);
        });
      }).then((_) {
        return store2.get(2).then((value) {
          expect(value, false);
        });
      }).then((_) {
        return reOpen(db).then((_) {
          return store1.get(1).then((value) {
            expect(value, "hi");
          });
        }).then((_) {
          return store2.get(1).then((value) {
            expect(value, "ho");
          });
        });
      });
    });

    test('bool', () async {
      var store = db.getStore("test");
      await store.put(true, 1);
      expect(await store.get(1), isTrue);
      await store.put(false, 1);
      expect(await store.get(1), isFalse);
      await store.put(null, 1);
      expect(await store.get(1), isNull);
    });

    test('records', () {
      var store = db.getStore("test");
      return store.put("hi").then((key) {
        int count = 0;
        return store.records
            .listen((record) {
              expect(record.value, "hi");
              count++;
            })
            .asFuture()
            .then((_) {
              expect(count, 1);
            });
      });
    });
  });
}
