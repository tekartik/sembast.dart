library sembast.store_test;

// basically same as the io runner but with extra output
// ignore_for_file: implementation_imports
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/sort.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('sort', () {
    late Database db;

    setUp(() async {
      db = await setupForTest(ctx, 'sort.db');
    });

    tearDown(() {
      return db.close();
    });

    int compareInt(int i1, int i2) => i1 - i2;

    test('sort', () async {
      var list = [3, 1, 2];
      list.sort(compareInt);
      expect(list, [1, 2, 3]);
    });

    test('Sort.sort', () async {
      var cooperator = Cooperator();
      var sort = Sort(cooperator);
      var list = [3, 1, 2];
      await sort.sort(list, compareInt);
      expect(list, [1, 2, 3]);
      cooperator.stop();
    });

    test('findSortedIndex', () {
      var list = <int>[];
      int intCompareFn(int i1, int i2) => i1 - i2;
      expect(findSortedIndex(list, 1, intCompareFn), 0);
      expect(findSortedIndex([1, 2], 1, intCompareFn), 0);
      expect(findSortedIndex([0, 2], 1, intCompareFn), 1);
      expect(findSortedIndex([0], 1, intCompareFn), 1);
      expect(findSortedIndex([1], 0, intCompareFn), 0);

      expect(findSortedIndex([2, 4, 6, 8, 10], 1, intCompareFn), 0);
      expect(findSortedIndex([2, 4, 6, 8, 10], 3, intCompareFn), 1);
      expect(findSortedIndex([2, 4, 6, 8, 10], 5, intCompareFn), 2);
      expect(findSortedIndex([2, 4, 6, 8, 10], 7, intCompareFn), 3);
      expect(findSortedIndex([2, 4, 6, 8, 10], 9, intCompareFn), 4);
      expect(findSortedIndex([2, 4, 6, 8, 10], 11, intCompareFn), 5);

      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 1, intCompareFn), 0);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 3, intCompareFn), 1);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 5, intCompareFn), 2);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 7, intCompareFn), 3);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 9, intCompareFn), 4);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 11, intCompareFn), 5);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 13, intCompareFn), 6);
    });
  });
}
