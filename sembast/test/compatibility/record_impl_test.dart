library sembast.record_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sembast_impl.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('record_impl', () {
    group('db', () {
      Database db;

      setUp(() async {
        db = await setupForTest(ctx);
      });

      tearDown(() {
        return db.close();
      });
    });

    group('no_db', () {
      test('immutable', () {
        //var store = StoreRef<dynamic, dynamic> store = db.mainStore;
        ImmutableSembastRecord record =
            ImmutableSembastRecord(mainStoreRef.record(1), 'hi');
        expect(record.ref.store.name, '_main');
        expect(record.key, 1);
        expect(record.value, 'hi');
        try {
          // ignore: deprecated_member_use_from_same_package
          record.store;
          fail('should fail');
        } on UnsupportedError catch (_) {}
        try {
          record.value = 'ho';
          fail('should fail');
        } on StateError catch (_) {}
        try {
          record['field'] = 'value';
          fail('should fail');
        } on StateError catch (_) {}

        expect(record.toDatabaseRowMap(), {'key': 1, 'value': 'hi'});

        var clone = record.clone();
        expect(clone.key, 1);
        expect(clone.value, 'hi');
        expect(clone.ref.store.name, '_main');
      });

      test('immutable_value', () {
        ImmutableSembastRecord record =
            ImmutableSembastRecord(mainStoreRef.record(1), {'foo': 'bar'});
        var map = record.value as Map;
        try {
          map['foo'] = 'doe';
          fail('should fail');
        } on StateError catch (_) {}
        expect(record.value, {'foo': 'bar'});
      });

      test('lazy muttable', () {
        ImmutableSembastRecord record =
            ImmutableSembastRecord(mainStoreRef.record(1), {'foo': 'bar'});
        var lazy = makeLazyMutableRecord(null, record);
        expect(lazy.value, {'foo': 'bar'});
        lazy['test'] = 1;
        expect(lazy.value, {'foo': 'bar', 'test': 1});
      });
    });
  });
}
