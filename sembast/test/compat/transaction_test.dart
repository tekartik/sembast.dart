library sembast.compat.transaction_test;

// ignore_for_file: deprecated_member_use_from_same_package

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('compat_transaction', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'compat/transaction.db');
    });

    tearDown(() {
      return db.close();
    });

    test('put no await', () async {
      Transaction transaction;
      await db.transaction((txn) {
        transaction = txn;
      });
      try {
        await transaction.put('test');
        fail('first put should fail');
      } on StateError catch (_) {}
    });
  });
}
