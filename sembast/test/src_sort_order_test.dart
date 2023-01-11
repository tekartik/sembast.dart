library sembast.src_filter_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';

import 'test_common.dart';

// Bad definition on purpose.
var store = StoreRef<Object?, Object?>.main();
var record = store.record(1);

void main() {
  group('src_sort_order_test', () {
    test('with_dot', () {
      var field = FieldKey.escape('my.field');
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(record, {'my.field': 1});
      var record2 = SembastRecordSnapshot(record, {'my.field': 2});
      expect(sortOrder.compareAscending(record1, record2), -1);
      expect(sortOrder.compareAscending(record2, record1), 1);
    });

    test('sub.field', () {
      var field = 'my.field';
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(record, {
        'my': {'field': 1}
      });
      var record2 = SembastRecordSnapshot(record, {
        'my': {'field': 2}
      });
      expect(sortOrder.compareAscending(record1, record2), -1);
    });

    test('different type.field', () {
      var field = 'field';
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(record, {'field': 1});
      var record2 = SembastRecordSnapshot(record, {'field': '2'});
      expect(sortOrder.compareAscending(record1, record2), -1);
    });
  });
}
