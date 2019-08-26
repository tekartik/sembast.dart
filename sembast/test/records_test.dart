library sembast.store_test;

// basically same as the io runner but with extra output
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('records', () {
    Database db;
    var store = StoreRef<int, String>.main();

    setUp(() async {
      db = await setupForTest(ctx, 'records.db');
    });

    tearDown(() {
      return db.close();
    });

    test('none', () async {
      var records = store.records([]);
      expect(await records.get(db), isEmpty);
      expect(await records.getSnapshots(db), isEmpty);
      expect(await records.delete(db), isEmpty);
    });

    test('one', () async {
      var records = store.records([1]);
      expect(records[0].key, 1);
      expect(await records.get(db), [null]);
      expect(await records.getSnapshots(db), [null]);
      expect(await records.delete(db), [null]);

      expect(await records.put(db, ['test']), ['test']);
      expect(await records.get(db), ['test']);
      expect((await records.getSnapshots(db)).map((record) => record.value),
          ['test']);
      expect(await records.delete(db), [1]);
      expect(await records.get(db), [null]);
    });

    test('two_one_missing', () async {
      var records = store.records([1]);
      expect(await records.put(db, ['test']), ['test']);

      records = store.records([1, 2]);
      expect(await records.get(db), ['test', null]);
      var snapshots = await records.getSnapshots(db);
      expect(snapshots[0].value, 'test');
      expect(snapshots[1], isNull);
      expect(await records.delete(db), [1, null]);
      expect(await records.get(db), [null, null]);
    });
  });
}
