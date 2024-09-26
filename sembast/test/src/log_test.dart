library;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/log_level.dart';

import '../fs_test_common.dart';
import '../test_common.dart';

void main() {
  defineTests(memoryFsDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('log_level', () {
    late Database db;

    var store = StoreRef<int, String>.main();
    var record = store.record(1);
    setUp(() async {
      sembastLogLevel = SembastLogLevel.verbose;
      db = await setupForTest(ctx, 'log_level.db');
    });

    tearDown(() async {
      await db.close();
      sembastLogLevel = SembastLogLevel.none;
    });

    test('put/read', () async {
      await record.put(db, 'test');
      await record.get(db);
    });
  });
}
