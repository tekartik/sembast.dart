library sembast.exception_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('exception', () {
    Database db;

    tearDown(() {
      db.close();
    });

    test('put', () async {
      db = await ctx.open();
      try {
        await db.put(new DateTime.now());
        fail("should fail");
      } on DatabaseException catch (_) {}
    });
  });
}
