library sembast.record_test;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/sembast.dart';

import 'test_common.dart';
// ignore_for_file: deprecated_member_use_from_same_package

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_demo', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/record_demo.db');
    });

    tearDown(() {
      return db.close();
    });

    test('demo', () async {
      final store = db.getStore('my_store');
      var record = Record(store, {'name': 'ugly'});
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
