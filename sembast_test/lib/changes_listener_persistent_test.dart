// basically same as the io runner but with extra output

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var store = StoreRef<int, int>('test');
  var storeDup = StoreRef<int, int>('test_dup');
  var record = store.record(1);

  group('changes_listener_persistent', () {
    tearDown(() async {});
    test('simple_add', () async {
      var db = await setupForTest(ctx, 'changes_listener_persistent_add.db');

      Future<void> onChanges(
        Transaction txn,
        List<RecordChange> changes,
      ) async {
        for (var change in changes) {
          await storeDup
              .record(change.ref.key as int)
              .put(txn, change.newValue as int);
        }
      }

      store.addOnChangesListener(db, onChanges);
      expect(await storeDup.record(1).get(db), isNull);
      await record.add(db, 2);
      expect(await storeDup.record(1).get(db), 2);
      db = await reOpen(db);
      expect(await storeDup.record(1).get(db), 2);
      await db.close();
    });
  });
}
