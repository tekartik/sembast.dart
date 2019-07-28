library sembast.compat.store_test;

// ignore_for_file: deprecated_member_use_from_same_package
// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_store', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/store.db');
    });

    tearDown(() {
      return db.close();
    });

    test('clear', () async {
      Store store = db.getStore("test");
      await store.put("hi", 1);
      await store.clear();
      expect(await store.get(1), isNull);
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

    test('delete_main', () async {
      var mainStoreName = db.mainStore.name;
      Store store = db.findStore(mainStoreName);
      expect(store, isNotNull);
      expect(db.stores, [db.mainStore]);
      await db.deleteStore(mainStoreName);
      expect(db.stores, [db.mainStore]);
      expect(db.findStore(mainStoreName), isNotNull);
    });

    test('delete_null', () {
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

    test('put/delete_store', () async {
      Store store = db.getStore("test_store");
      await store.put('test', 1);
      await db.deleteStore('test_store');
      store = db.getStore("test_store");
      expect(await store.get(1), isNull);
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
