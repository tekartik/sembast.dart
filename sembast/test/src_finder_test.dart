library;

import 'package:sembast/src/finder_impl.dart';
import 'package:sembast/src/record_impl.dart';

import 'test_common.dart';

Iterable<RecordSnapshot> filterMatchingBoundary(
        SembastFinder finder, List<RecordSnapshot> snapshots) =>
    snapshots
        .where((element) => finderMatchesFilterAndBoundaries(finder, element));

void main() {
  group('finder', () {
    group('boundary', () {
      var store = StoreRef<int, int>.main();

      var record1 = ImmutableSembastRecord(store.record(1), 1000);
      var record2 = ImmutableSembastRecord(store.record(2), 1001);
      var record3 = ImmutableSembastRecord(store.record(3), 1001);

      test('boundaryStart', () async {
        var finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [1001]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            <RecordSnapshot>[]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [1000]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            [record2, record3]);

        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            start: Boundary(values: [999]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            [record1, record2, record3]);
      });
      test('boundaryEnd', () async {
        var finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1001]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            [record1]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1000]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            <RecordSnapshot>[]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1000], include: true));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            [record1]);
        finder = SembastFinder(
            sortOrders: [SortOrder(Field.value)],
            end: Boundary(values: [1002]));
        expect(filterMatchingBoundary(finder, [record1, record2, record3]),
            [record1, record2, record3]);
      });
    });
    test('toString()', () {
      var finder =
          Finder(sortOrders: [SortOrder('test')], start: Boundary(values: [1]));
      expect(finder.toString(),
          'Finder({sort: [{test: asc}], start: {values: [1], include: false}})');
    });
  });
}
