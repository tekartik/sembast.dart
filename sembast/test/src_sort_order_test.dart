library sembast.src_filter_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';

import 'test_common.dart';

var store = StoreRef.main();
var record = store.record(1);

void main() {
  group('src_sort_order_test', () {
    test('with_dot', () {
      var field = FieldKey.escape('my.field');
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(null, {'my.field': 1});
      var record2 = SembastRecordSnapshot(null, {'my.field': 2});
      expect(sortOrder.compareAscending(record1, record2), -1);
    });

    test('sub.field', () {
      var field = 'my.field';
      var sortOrder = SembastSortOrder(field);
      var record1 = SembastRecordSnapshot(null, {
        'my': {'field': 1}
      });
      var record2 = SembastRecordSnapshot(null, {
        'my': {'field': 2}
      });
      expect(sortOrder.compareAscending(record1, record2), -1);
    });
  });
}
