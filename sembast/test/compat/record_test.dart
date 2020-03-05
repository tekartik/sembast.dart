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
  });
}
