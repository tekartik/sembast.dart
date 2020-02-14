library sembast.compat.crud_impl_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/database_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('crud_impl', () {
    SembastDatabase db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/crud_impl.db') as SembastDatabase;
    });

    tearDown(() {
      return db.close();
    });

    test('put_close_get', () {
      return db.put('hi', 1).then((_) {
        return db.reOpen().then((_db) {
          db = _db as SembastDatabase;
          return db.get(1).then((value) {
            expect(value, 'hi');
          });
        });
      });
    });

    test('put_nokey_close_put', () {
      return db.put('hi').then((key) {
        return db.reOpen().then((_db) {
          db = _db as SembastDatabase;
          return db.put('hi').then((key) {
            expect(key, 2);
          });
        });
      });
    });

    test('put_update_close_get', () {
      return db.put('hi', 1).then((_) {
        return db.put('ho', 1).then((_) {
          return db.reOpen().then((_db) {
            db = _db as SembastDatabase;
            return db.get(1).then((value) {
              expect(value, 'ho');
              return db.count().then((int count) {
                expect(count, 1);
              });
            });
          });
        });
      });
    });

    test('put_delete_close_get', () {
      return db.put('hi', 1).then((_) {
        return db.delete(1).then((key) {
          return db.reOpen().then((_db) {
            db = _db as SembastDatabase;
            return db.get(1).then((value) {
              expect(value, isNull);
              return db.count().then((int count) {
                expect(count, 0);
              });
            });
          });
        });
      });
    });

    test('put_close_get_key_string', () {
      return db.put('hi', '1').then((_) {
        return db.reOpen().then((_db) {
          db = _db as SembastDatabase;
          return db.get('1').then((value) {
            expect(value, 'hi');
          });
        });
      });
    });

    test('put_close_get_map', () {
      final info = {'info': 12};
      return db.put(info, 1).then((_) {
        return db.reOpen().then((_db) {
          db = _db as SembastDatabase;
          return db.get(1).then((infoRead) {
            expect(infoRead, info);
            expect(identical(infoRead, info), isFalse);
          });
        });
      });
    });
  });
}
