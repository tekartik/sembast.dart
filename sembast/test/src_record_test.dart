import 'package:sembast/src/record_impl.dart';

import 'test_common.dart';

void main() {
  group('src_record', () {
    test('toDatabaseRowMap', () {
      var record = ImmutableSembastRecord(
        StoreRef<int, Object>.main().record(1),
        'val',
      );
      expect(record.toDatabaseRowMap(), {'key': 1, 'value': 'val'});
      // ignore: deprecated_member_use_from_same_package
      expect(record.deleted, isFalse);
      record = ImmutableSembastRecord(
        StoreRef<int, Object>.main().record(1),
        'dummy',
      );
      expect(record.toDatabaseRowMap(), {'key': 1, 'value': 'dummy'});
      record = ImmutableSembastRecord(
        StoreRef<int, Object>.main().record(1),
        'dummy',
        deleted: true,
      );
      expect(record.toDatabaseRowMap(), {'key': 1, 'deleted': true});
      record = ImmutableSembastRecord(
        StoreRef<int, Object>.main().record(1),
        'dummy',
        deleted: false,
      );
      expect(record.toDatabaseRowMap(), {'key': 1, 'value': 'dummy'});
      record = ImmutableSembastRecord(
        StoreRef<int, Object>('st').record(1),
        'val',
      );
      expect(record.toDatabaseRowMap(), {
        'key': 1,
        'store': 'st',
        'value': 'val',
      });
    });
    test('toDatabaseRowMap', () {
      var map = {'key': 1, 'deleted': true};
      var record = ImmutableSembastRecord.fromDatabaseRowMap(map);
      expect(record.key, 1);
      expect(record.deleted, true);
      expect(record.toDatabaseRowMap(), map);
      map = {'key': 1, 'store': 'st', 'value': 'val'};
      record = ImmutableSembastRecord.fromDatabaseRowMap(map);
      expect(record.key, 1);
      expect(record.value, 'val');
      expect(record.ref.store.name, 'st');
      expect(record.toDatabaseRowMap(), map);
    });
  });
}
