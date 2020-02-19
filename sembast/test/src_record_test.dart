import 'package:sembast/src/record_impl.dart';

import 'test_common.dart';

void main() {
  group('src_record', () {
    test('toDatabaseRowMap', () {
      var record = ImmutableSembastRecord(StoreRef.main().record(1), 'val');
      expect(record.toDatabaseRowMap(), {'key': 1, 'value': 'val'});
      // ignore: deprecated_member_use_from_same_package
      expect(record.deleted, isFalse);
      record = ImmutableSembastRecord(StoreRef.main().record(1), null);
      expect(record.toDatabaseRowMap(), {'key': 1});
      record = ImmutableSembastRecord(StoreRef.main().record(1), null,
          deleted: true);
      expect(record.toDatabaseRowMap(), {'key': 1, 'deleted': true});
      record = ImmutableSembastRecord(StoreRef.main().record(1), null,
          deleted: false);
      expect(record.toDatabaseRowMap(), {'key': 1});
      record = ImmutableSembastRecord(StoreRef('st').record(1), 'val');
      expect(
          record.toDatabaseRowMap(), {'key': 1, 'store': 'st', 'value': 'val'});
    });
  });
}
