library sembast.transaction_deprecated_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('transaction_deprecated', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });
  });

  group('find_deprecated', () {
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

    tearDown(_tearDown);
  });
}
