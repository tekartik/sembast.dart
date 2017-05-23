library sembast.record_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_demo', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('demo', () async {
      Store store = db.getStore("my_store");
      Record record = new Record(store, {"name": "ugly"});
      record = await db.putRecord(record);
      expect(record, isNotNull);
      record = await db.getStoreRecord(store, record.key);
      expect(record, isNotNull);
      record = (await db.findStoreRecords(
              store, new Finder(filter: new Filter.byKey(record.key))))
          .first;
      expect(record, isNotNull);
      await db.deleteRecord(record);
      record = await db.getStoreRecord(store, record.key);
      expect(record, isNull);
    });
  });
}
