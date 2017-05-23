library sembast.record_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('field', () {
      expect(Field.key, "_key");
      expect(Field.value, "_value");
    });

    test('properties', () {
      Store store = db.mainStore;
      Record record = new Record(store, "hi", 1);
      expect(record.store, store);
      expect(record.key, 1);
      expect(record.value, "hi");
      expect(record[Field.value], "hi");
      expect(record[Field.key], 1);

      record =
          new Record(store, {"text": "hi", "int": 1, "bool": true}, "mykey");

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
    });

    test('put database', () {
      Record record1 = new Record(null, "hi");
      return db.putRecord(record1).then((inserted) {
        expect(record1.store, isNull);
        expect(record1.key, isNull);
        expect(inserted.key, 1);
        expect(inserted.store, db.mainStore);
      });
    });

    test('put/delete multiple', () {
      Store store = db.mainStore;
      Record record1 = new Record(store, "hi", 1);
      Record record2 = new Record(store, "ho", 2);
      Record record3 = new Record(store, "ha", 3);
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
        return store.deleteAll([1, 4, 2]).then((List keys) {
          expect(keys, [1, 2]);
          return store.count().then((count) {
            expect(count, 1);
          });
        });
      });
    });

    test('put/get/delete', () {
      Store store = db.mainStore;
      Record record = new Record(store, "hi");
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
