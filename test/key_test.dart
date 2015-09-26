library sembast.key_test;

// basically same as the io runner but with extra output
import 'package:test/test.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseFactory);
}

void defineTests(DatabaseFactory factory) {
  group('key', () {
    Database db;

    setUp(() async {
      db = await setupForTest(factory);
    });

    tearDown(() {
      db.close();
    });

    test('null', () async {
      int key = await db.put("test");
      expect(key, 1);
      key = await db.put("test");
      expect(key, 2);
    });

    test('int', () async {
      int key = await db.put("test", 2);
      expect(key, 2);
      // next will increment
      key = await db.put("test");
      expect(key, 3);
    });

    test('string', () async {
      String key = await db.put("test", "key1");
      expect(key, "key1");
      // next will increment
      int key1 = await db.put("test");
      expect(key1, 1);
    });

    test('double', () async {
      double key = await db.put("test", 1.2);
      expect(await db.get(1.2), "test");
      // next will increment
      int key1 = await db.put("test");
      expect(key1, 1);
    });

    test('double_rounded', () async {
      double key = await db.put("test", 2.0);
      expect(await db.get(2.0), "test");
      // next will increment
      int key1 = await db.put("test");
      // in dart2js this increases!
      expect(key1 == 1 || key1 == 3, isTrue);
    });
  });
}
