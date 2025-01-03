library;

import 'package:path/path.dart';

import 'test_common.dart';

void main() {
  defineDatabaseClientTests(memoryDatabaseContext);
}

void defineDatabaseClientTests(DatabaseTestContext ctx) {
  /// worst definition ever, on purpose...
  var store = StoreRef<int, String>.main();

  group('database_client', () {
    group('opened', () {
      late Database db;

      setUp(() async {
        db = await setupForTest(ctx, join('database_client', 'opened.db'));
      });

      tearDown(() {
        return db.close();
      });

      test('db.dropAll', () async {
        await store.record(1).put(db, 'test');
        expect(store.countSync(db), 1);
        await db.dropAll();
        expect(store.countSync(db), 0);
      });
      test('txn.dropAll', () async {
        await db.transaction((txn) async {
          await store.record(1).put(txn, 'test');
          expect(store.countSync(txn), 1);
          await txn.dropAll();
          expect(store.countSync(txn), 0);
        });
        expect(store.countSync(db), 0);
      });
    });
  });
}
