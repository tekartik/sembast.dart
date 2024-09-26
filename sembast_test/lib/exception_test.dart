library;

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('exception', () {
    Database? db;

    tearDown(() {
      return db?.close();
    });

    test('put', () async {
      db = await setupForTest(ctx, 'exception/put_date_time.db');
      try {
        await StoreRef<Object, Object>.main().add(db!, DateTime.now());
        fail('should fail');
      } on ArgumentError catch (_) {}
    });
  });
}
