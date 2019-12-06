library sembast.compat.key_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_key', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/key.db');
    });

    tearDown(() {
      return db.close();
    });

    test('null', () async {
      var key = await db.put('test') as int;
      expect(key, 1);
      key = await db.put('test') as int;
      expect(key, 2);
    });

    test('int', () async {
      var key = await db.put('test', 2) as int;
      expect(key, 2);
      // next will increment
      key = await db.put('test') as int;
      expect(key, 3);
    });

    test('string', () async {
      final key = await db.put('test', 'key1') as String;
      expect(key, 'key1');
      // next will increment
      final key1 = await db.put('test') as int;
      expect(key1, 1);
    });

    test('double', () async {
      await db.put('test', 1.2);
      expect(await db.get(1.2), 'test');
      // next will increment
      final key1 = await db.put('test') as int;
      expect(key1, 1);
    });

    test('double_rounded', () async {
      await db.put('test', 2.0);
      expect(await db.get(2.0), 'test');
      // next will increment
      final key1 = await db.put('test') as int;
      // in dart2js this increases!
      expect(key1 == 1 || key1 == 3, isTrue);
    });
  });
}
