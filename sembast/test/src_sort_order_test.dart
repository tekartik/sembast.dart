library;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'test_common.dart';

// Bad definition on purpose.
var store = SembastStoreRef<Object?, Object?>(dbMainStore);
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

    test('sub.0', () {
      var field = 'my.0';
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(record, {
        'my': [1]
      });
      var record2 = SembastRecordSnapshot(record, {
        'my': [2]
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

    test('custom', () {
      var field = Field.value;
      var record1 = SembastRecordSnapshot(record, '9');
      var record2 = SembastRecordSnapshot(record, '10');

      var sortOrder = SembastSortOrder(field);
      var sortOrderParseInt = SortOrder<String>.custom(
              field,
              (value1, value2) =>
                  int.parse(value1).compareTo(int.parse(value2)))
          as SembastSortOrder<String>;
      expect(sortOrder.compareAscending(record1, record2), greaterThan(0));
      expect(sortOrderParseInt.compareAscending(record1, record2), -1);
    });
  });
}
