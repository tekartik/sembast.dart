// ignore_for_file: invalid_use_of_visible_for_testing_member

library;

// ignore: implementation_imports
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/src/import_database.dart';

import 'test_common.dart';

final intStore = StoreRef<int, String>('test');

void main() {
  defineJdbConcurrentDatabaseTests(databaseTestContextJdbMemory);
}

void defineJdbConcurrentDatabaseTests(DatabaseTestContextJdb ctx) {
  group('jdb_concurrent_database', () {
    test('add', () async {
      var dbPath = 'concurrent.db';
      var db1 = await ctx.deleteAndOpen(dbPath);
      var factory = ctx.factory.mixin;

      /// Force opening new instance.
      factory.removeDatabaseOpenHelper(dbPath);
      var db2 = await ctx.open(dbPath);

      await intStore.record(1).put(db1, 'test1');
      await intStore.record(2).put(db2, 'test2');
      expect(await intStore.record(1).get(db2), 'test1');
      // db1 not reloaded...
      expect(await intStore.record(2).get(db1), isNull);
      await db1.compact();
      expect(await intStore.record(2).get(db1), isNull);
      await db1.checkForChanges();
      expect(await intStore.record(2).get(db1), 'test2');
      await db1.close();
      await db2.close();
    });
    test('write after another instance compacted', () async {
      var dbPath = 'concurrent_compacted.db';
      var db1 = await ctx.deleteAndOpen(dbPath);
      var factory = ctx.factory.mixin;

      /// Force opening new instance.
      factory.removeDatabaseOpenHelper(dbPath);
      var db2 = await ctx.open(dbPath);

      await intStore.record(1).put(db1, 'a');
      await intStore.record(1).delete(db1);
      await intStore.record(3).put(db1, 'c');
      // The compacted entries are no longer available for a delta import.
      await db1.compact();
      // Full (non delta) reload
      await db2.checkForChanges();
      expect(await intStore.record(3).get(db2), 'c');
      // The full reload must update the known revision, otherwise each commit
      // sees a revision change and reloads again, forever.
      await intStore
          .record(2)
          .put(db2, 'b')
          .timeout(const Duration(seconds: 10));
      expect(await intStore.findKeys(db2), [2, 3]);
      await db1.checkForChanges();
      expect(await intStore.findKeys(db1), [2, 3]);
      await db1.close();
      await db2.close();
    });
    test('listener', () async {
      var dbPath = 'concurrent.db';
      var db1 = await ctx.deleteAndOpen(dbPath);
      var factory = ctx.factory as SembastDatabaseFactoryMixin;

      /// Force opening new instance.
      factory.removeDatabaseOpenHelper(dbPath);
      var db2 = await ctx.open(dbPath);

      late List events;
      var db1Subscription = intStore.query().onSnapshots(db1).listen((
        snapshots,
      ) {
        events = snapshots;
        // print('db1: $event');
      });
      await intStore.record(1).put(db1, 'test1');
      await intStore.record(2).put(db2, 'test2');
      expect(await intStore.record(1).get(db2), 'test1');

      // db1 not reloaded...
      expect(await intStore.record(2).get(db1), isNull);
      await db1.compact();
      expect(await intStore.record(2).get(db1), isNull);
      expect(events, hasLength(1));
      await db1.checkForChanges();
      expect(await intStore.record(2).get(db1), 'test2');
      expect(events, hasLength(2));
      await db1.close();
      await db2.close();
      await db1Subscription.cancel();
    });
  });
}
