library sembast.database_test;

import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_impl.dart';

import 'test_common.dart';

void main() {
  group('store_impl', () {
    var store = StoreRef<int, int>.main();

    group('filter', () {
      var record1 = ImmutableSembastRecord(store.record(1), 1000);
      var record2 = ImmutableSembastRecord(store.record(2), 1001);
      var record3 = ImmutableSembastRecord(store.record(3), 1001);

      test('filterStart', () async {
        var finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [1001]));
        expect(
            await finderFilterStart(finder, [record1, record2, record3]), []);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [1000]));
        expect(await finderFilterStart(finder, [record1, record2, record3]),
            [record2, record3]);

        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [999]));
        expect(await finderFilterStart(finder, [record1, record2, record3]),
            [record1, record2, record3]);
      });
      test('filterEnd', () async {
        var finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1001]));
        expect(await finderFilterEnd(finder, [record1, record2, record3]),
            [record1]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1000]));
        expect(await finderFilterEnd(finder, [record1, record2, record3]), []);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1000], include: true));
        expect(await finderFilterEnd(finder, [record1, record2, record3]),
            [record1]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1002]));
        expect(await finderFilterEnd(finder, [record1, record2, record3]),
            [record1, record2, record3]);
      });
    });
  });
}
