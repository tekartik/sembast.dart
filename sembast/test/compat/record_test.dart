library sembast.record_test;

// ignore_for_file: deprecated_member_use_from_same_package
import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/record.db');
    });

    tearDown(() {
      return db.close();
    });

    test('field', () {
      expect(Field.key, '_key');
      expect(Field.value, '_value');
    });

    test('properties', () {
      final store = db.mainStore;
      var record = Record(store, 'hi', 1);
      expect(record.store, store);
      expect(record.key, 1);
      expect(record.value, 'hi');
      expect(record[Field.value], 'hi');
      expect(record[Field.key], 1);

      record = Record(store, {'text': 'hi', 'int': 1, 'bool': true}, 'mykey');

      expect(record.store, store);
      expect(record.key, 'mykey');
      expect(record.value, {'text': 'hi', 'int': 1, 'bool': true});
      expect(record[Field.value], record.value);
      expect(record[Field.key], record.key);
      expect(record['text'], 'hi');
      expect(record['int'], 1);
      expect(record['bool'], true);

      record['bool'] = false;
      expect(record['bool'], isFalse);
      record[Field.key] = 'newkey';
      record[Field.value] = 'newvalue';
      expect(record.key, 'newkey');
      expect(record.value, 'newvalue');
      record['test'] = 1;
      expect(record.value, {'test': 1});
      expect(record['path.sub'], isNull);
      record['path.sub'] = 2;
      expect(record.value, {
        'test': 1,
        'path': {'sub': 2}
      });
      expect(record['path.sub'], 2);
    });

    test('put multi database', () async {
      final record = Record(null, 'hi');
      final inserted = (await db.putRecords([record])).first;
      expect(record.store, isNull);
      expect(record.key, isNull);
      expect(inserted.key, 1);
      expect(inserted.store, db.mainStore);
    });

    test('put multi transaction', () async {
      await db.transaction((txn) async {
        final record = Record(null, 'hi');
        final inserted = (await txn.putRecords([record])).first;
        expect(record.store, isNull);
        expect(record.key, isNull);
        expect(inserted.key, 1);
        // !!weird no?
        expect(inserted.store, db.mainStore);
      });
    });

    test('put/delete multiple', () {
      final store = db.mainStore;
      final record1 = Record(store, 'hi', 1);
      final record2 = Record(store, 'ho', 2);
      final record3 = Record(store, 'ha', 3);
      return db.putRecords([record1, record2, record3]).then(
          (List<Record> inserted) {
        expect(inserted.length, 3);
        expect(inserted[0].key, 1);

        return store.getRecords([1, 4, 3]).then((List<Record> got) {
          expect(got.length, 3);
          expect(got[0].key, 1);
          expect(got[1], null);
          expect(got[2].key, 3);
        });
      }).then((_) {
        return store.deleteAll([1, 4, 2]).then((keys) {
          expect(keys, [1, null, 2]);
          return store.count().then((count) {
            expect(count, 1);
          });
        });
      });
    });

  });
}
