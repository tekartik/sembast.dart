library sembast.key_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('key', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'key.db');
    });

    tearDown(() {
      return db.close();
    });

    test('dynamic', () async {
      var store = StoreRef.main();
      int key = await store.add(db, "test") as int;
      expect(key, 1);
      key = await store.add(db, "test") as int;
      expect(key, 2);
    });

    test('dynamic_rounded', () async {
      var store = StoreRef.main();
      var key = await store.record(2.0).put(db, "test");
      expect(key, 2.0);
      expect(await store.record(2.0).get(db), "test");
      // next will increment (or restart from 1 in js
      int intKey = await store.add(db, "test") as int;
      if (isJavascriptVm) {
        expect(intKey, 3);
      } else {
        expect(intKey, 1);
      }
    });

    test('int', () async {
      var store = StoreRef<int, String>.main();
      int key = await store.record(2).put(db, "test");
      expect(key, 2);
      // next will increment
      key = await store.add(db, "test");
      expect(key, 3);

      // Tweak to restart from 1 and make sure the existing keys are skipped
      ((db as SembastDatabase).mainStore as SembastStore).lastIntKey = 0;
      key = await store.add(db, "test");
      expect(key, 1);
      key = await store.add(db, "test");
      expect(key, 4);
    });

    test('string', () async {
      var store = StoreRef<String, String>.main();
      var key = await store.add(db, "test");
      expect(key, const TypeMatcher<String>());
      key = await store.add(db, "test");
      expect(key, const TypeMatcher<String>());
      expect(await store.count(db), 2);
      /*
      String key = await db.put("test", "key1") as String;
      expect(key, "key1");
      // next will increment
      int key1 = await db.put("test") as int;
      expect(key1, 1);
      */
    });

    test('double', () async {
      var store = StoreRef<double, String>.main();
      await store.record(1.2).put(db, "test");
      expect(await store.record(1.2).get(db), "test");
      try {
        var key = await store.add(db, 'test');
        if (isJavascriptVm) {
          expect(key, 1);
        } else {
          fail('should fail');
        }
      } on ArgumentError catch (_) {}
    });
  });
}
