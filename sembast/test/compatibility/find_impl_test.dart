library sembast.find_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/settings_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('find', () {
    Database db;

    Future _tearDown() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    }

    Store store;
    Record record1, record2, record3;
    setUp(() async {
      db = await setupForTest(ctx);
      store = db.mainStore;
      record1 = Record(store, "hi", 1);
      record2 = Record(store, "ho", 2);
      record3 = Record(store, "ha", 3);
      return db.putRecords([record1, record2, record3]);
    });

    group('find_complex', () {
      Database db;
      Store store;
      Record record1, record2, record3;
      setUp(() async {
        db = await setupForTest(ctx);
        store = db.mainStore;
        record1 = Record(store, {"text": "hi", "value": 1}, 1);
        record2 = Record(store, {"text": "ho", "value": 2}, 2);
        record3 = Record(store, {"text": "ha", "value": 2}, 3);
        return db.putRecords([record1, record2, record3]);
      });

      tearDown(_tearDown);

      test('readOnly', () async {
        await db.close();
        db = await ctx.factory.openDatabase(db.path,
            settings: DatabaseSettings()..readImmutable = true);
        var openHelper = (db as SembastDatabase).openHelper;
        (db as SembastDatabase).openHelper = DatabaseOpenHelper(
            openHelper.factory,
            openHelper.path,
            DatabaseOpenOptions(
                settings: DatabaseSettings()..readImmutable = true));
        var record = await db.findRecord(Finder());
        try {
          record['text'] = 'hu';
          fail('should fail');
        } on StateError catch (_) {}
        record = record.clone();
        record['text'] = 'hu';
      });
    });
  });
}
