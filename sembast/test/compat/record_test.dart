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
  });
}
