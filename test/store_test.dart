library sembast.store_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
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
      db.close();
    });

    test('clear', () {
      Store store = db.getStore("test");
      return store.put("hi", 1).then((_) {
        return store.clear();
      }).then((_) {
        return store.get(1).then((value) {
          expect(value, null);
        });
      });
    });

    test('delete', () {
      Store store = db.getStore("test");
      expect(store, isNotNull);
      return db.deleteStore("test").then((_) {
        expect(db.findStore("test"), isNull);
      });
    });

    test('delete_main', () {
      Store store = db.getStore(null);
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

    test('put/get', () {
      Store store1 = db.getStore("test1");
      Store store2 = db.getStore("test2");
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
      Store store = db.getStore("test");
      await store.put(true, 1);
      expect(await store.get(1), isTrue);
      await store.put(false, 1);
      expect(await store.get(1), isFalse);
      await store.put(null, 1);
      expect(await store.get(1), isNull);
    });

    test('records', () {
      Store store = db.getStore("test");
      return store.put("hi").then((key) {
        int count = 0;
        return store.records
            .listen((Record record) {
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
