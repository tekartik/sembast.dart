library sembast.compat.crud_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_crud', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/crud.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put', () {
      return db.put('hi', 1).then((key) {
        expect(key, 1);
      });
    });

    test('update', () async {
      // update none
      expect(await db.update('hi', 1), isNull);
      await db.put('hi', 1);
      expect(await db.update('ho', 1), 'ho');
    });

    test('update_map', () async {
      // update none
      var key = await db.put({'test': 1});
      expect(await db.update({'new': 2}, key), {'test': 1, 'new': 2});
      expect(await db.update({'new': FieldValue.delete, 'a.b.c': 3}, key), {
        'test': 1,
        'a': {
          'b': {'c': 3}
        }
      });
    });
    test('put_nokey', () async {
      var key = await db.put('hi');
      expect(key, 1);
      var key2 = await db.put('hi');
      expect(key2, 2);
    });
  });
}
