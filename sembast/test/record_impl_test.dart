library;

// basically same as the io runner but with extra output
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_impl', () {
    group('db', () {
      late Database db;

      setUp(() async {
        db = await setupForTest(ctx, 'record_impl.db');
      });

      tearDown(() {
        return db.close();
      });
    });

    group('no_db', () {
      test('immutable_value', () {
        final record = ImmutableSembastRecord(mainStoreRef.record(1), {
          'foo': 'bar',
        });
        var map = record.value as Map;
        try {
          map['foo'] = 'doe';
          fail('should fail');
        } on StateError catch (_) {}
        expect(record.value, {'foo': 'bar'});
      });
    });
  });
}
