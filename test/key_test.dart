library sembast.key_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('key', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      db.close();
    });

    test('null', () async {
      int key = await db.put("test") as int;
      expect(key, 1);
      key = await db.put("test") as int;
      expect(key, 2);
    });

    test('int', () async {
      int key = await db.put("test", 2) as int;
      expect(key, 2);
      // next will increment
      key = await db.put("test") as int;
      expect(key, 3);
    });

    test('string', () async {
      String key = await db.put("test", "key1") as String;
      expect(key, "key1");
      // next will increment
      int key1 = await db.put("test") as int;
      expect(key1, 1);
    });

    test('double', () async {
      await db.put("test", 1.2);
      expect(await db.get(1.2), "test");
      // next will increment
      int key1 = await db.put("test") as int;
      expect(key1, 1);
    });

    test('double_rounded', () async {
      await db.put("test", 2.0);
      expect(await db.get(2.0), "test");
      // next will increment
      int key1 = await db.put("test") as int;
      // in dart2js this increases!
      expect(key1 == 1 || key1 == 3, isTrue);
    });
  });
}
