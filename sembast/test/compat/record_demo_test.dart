library sembast.record_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(devMemoryDatabaseContext);
}

void defineTests(DevDatabaseTestContext ctx) {
  group('record_demo', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('demo', () async {
      Store store = db.getStore("my_store");
      Record record = Record(store, {"name": "ugly"});
      record = await db.putRecord(record);
      expect(record, isNotNull);
      record = await store.getRecord(record.key);
      expect(record, isNotNull);
      record =
          (await store.findRecords(Finder(filter: Filter.byKey(record.key))))
              .first;
      expect(record, isNotNull);
      await db.deleteRecord(record);
      record = await store.getRecord(record.key);
      expect(record, isNull);
    });
  });
}
