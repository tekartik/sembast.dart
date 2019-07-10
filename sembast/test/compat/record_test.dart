library sembast.record_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(devMemoryDatabaseContext);
}

void defineTests(DevDatabaseTestContext ctx) {
  group('record', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('field', () {
      expect(Field.key, "_key");
      expect(Field.value, "_value");
    });

    test('properties', () {
      Store store = db.mainStore;
      Record record = Record(store, "hi", 1);
      expect(record.store, store);
      expect(record.key, 1);
      expect(record.value, "hi");
      expect(record[Field.value], "hi");
      expect(record[Field.key], 1);

      record = Record(store, {"text": "hi", "int": 1, "bool": true}, "mykey");

      expect(record.store, store);
      expect(record.key, "mykey");
      expect(record.value, {"text": "hi", "int": 1, "bool": true});
      expect(record[Field.value], record.value);
      expect(record[Field.key], record.key);
      expect(record["text"], "hi");
      expect(record["int"], 1);
      expect(record["bool"], true);

      record["bool"] = false;
      expect(record["bool"], isFalse);
      record[Field.key] = "newkey";
      record[Field.value] = "newvalue";
      expect(record.key, "newkey");
      expect(record.value, "newvalue");
      record['test'] = 1;
      expect(record.value, {'test': 1});
      expect(record['path.sub'], isNull);
      record['path.sub'] = 2;
      expect(record.value, {
        'test': 1,
        'path': {'sub': 2}
      });
      expect(record['path.sub'], 2);
    });

    test('update', () async {
      var record = Record(null, {"name": 'name1', 'test': 'test1'});
      record = await db.putRecord(record);
      var key = record.key;
      record = await db.getRecord(key);
      record['test'] = 'test2';
      await db.putRecord(record);
      expect((await db.getRecord(record.key)).value,
          {"name": 'name1', 'test': 'test2'});

      await db.transaction((txn) async {
        record = await txn.getRecord(key);
        record['test'] = 'test2';
        await txn.putRecord(record);
        expect((await txn.getRecord(record.key)).value,
            {"name": 'name1', 'test': 'test2'});
      });
    });
    test('put database', () async {
      Record record = Record(null, "hi");
      Record inserted = await db.putRecord(record);
      expect(record.store, isNull);
      expect(record.key, isNull);
      expect(inserted.key, 1);
      expect(inserted.store, db.mainStore);
    });

    test('put store', () async {
      var store = db.getStore('store');
      var record = Record(store, "hi");
      record = await db.putRecord(record);
      expect(record.store, store);
      expect(record.key, 1);

      record = await store.getRecord(record.key);
      expect(record.key, 1);
      expect(record.store, store);

      await db.transaction((txn) async {
        record = await txn.getStore(store.name).getRecord(record.key);
        expect(record.key, 1);
        expect(record.store, store);
        expect(record.value, 'hi');

        record = await txn.putRecord(record);
        expect(record.key, 1);
        expect(record.store, store);

        expect(record.key, 1);
        expect(record.store, store);

        await txn.getStore(store.name).put('ho', record.key);
        record = await txn.getStore(store.name).getRecord(record.key);
        expect(record.key, 1);
        expect(record.store, store);
        expect(record.value, 'ho');
      });
    });

    test('put multi database', () async {
      Record record = Record(null, "hi");
      Record inserted = (await db.putRecords([record])).first;
      expect(record.store, isNull);
      expect(record.key, isNull);
      expect(inserted.key, 1);
      expect(inserted.store, db.mainStore);
    });

    test('put transaction', () async {
      await db.transaction((txn) async {
        Record record = Record(null, "hi");
        Record inserted = await txn.putRecord(record);
        expect(record.store, isNull);
        expect(record.key, isNull);
        expect(inserted.key, 1);
        // !!weird no?
        expect(inserted.store, db.mainStore);
      });
    });

    test('put multi transaction', () async {
      await db.transaction((txn) async {
        Record record = Record(null, "hi");
        Record inserted = (await txn.putRecords([record])).first;
        expect(record.store, isNull);
        expect(record.key, isNull);
        expect(inserted.key, 1);
        // !!weird no?
        expect(inserted.store, db.mainStore);
      });
    });

    test('put/delete multiple', () {
      Store store = db.mainStore;
      Record record1 = Record(store, "hi", 1);
      Record record2 = Record(store, "ho", 2);
      Record record3 = Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]).then(
          (List<Record> inserted) {
        expect(inserted.length, 3);
        expect(inserted[0].key, 1);

        return store.getRecords([1, 4, 3]).then((List<Record> got) {
          expect(got.length, 2);
          expect(got[0].key, 1);
          expect(got[1].key, 3);
        });
      }).then((_) {
        return store.deleteAll([1, 4, 2]).then((keys) {
          expect(keys, [1, 2]);
          return store.count().then((count) {
            expect(count, 1);
          });
        });
      });
    });

    test('put/get/delete', () {
      Store store = db.mainStore;
      Record record = Record(store, "hi");
      return db.putRecord(record).then((Record insertedRecord) {
        expect(record.key, null);
        expect(insertedRecord.key, 1);
        expect(insertedRecord.value, "hi");
        expect(insertedRecord.deleted, false);
        expect(insertedRecord.store, store);
        return store.getRecord(insertedRecord.key).then((Record record) {
          expect(record.key, 1);
          expect(record.value, "hi");
          expect(record.deleted, false);
          expect(record.store, store);

          return store.delete(record.key).then((_) {
            // must not have changed
            expect(record.key, 1);
            expect(record.value, "hi");
            expect(record.deleted, false);
            expect(record.store, store);
          });
        });
      });
    });
  });
}
