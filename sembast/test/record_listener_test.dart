library sembast.store_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/database_impl.dart';

import 'compat/test_common.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_listener', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('onSnapshot', () async {
      var database = getDatabase(db);
      var store = StoreRef<int, String>.main();
      var record = store.record(1);

      expect(database.listener.isEmpty, isTrue);
      var sub = record.onSnapshot(db).listen((snapshot) {});
      expect(database.listener.isNotEmpty, isTrue);
      var sub2 = record.onSnapshot(db).listen((snapshot) {});
      await sub.cancel();
      expect(database.listener.isNotEmpty, isTrue);
      await sub2.cancel();
      expect(database.listener.isEmpty, isTrue);
    });
  });
}
