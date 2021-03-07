library sembast.store_test;

// basically same as the io runner but with extra output
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

    int _intCmp(int i1, int i2) => i1 - i2;

    test('sort', () async {
      var list = [3, 1, 2];
      list.sort(_intCmp);
      expect(list, [1, 2, 3]);
    });

    test('Sort.sort', () async {
      var cooperator = Cooperator();
      var sort = Sort(cooperator);
      var list = [3, 1, 2];
      await sort.sort(list, _intCmp);
      expect(list, [1, 2, 3]);
      cooperator.stop();
    });

    test('findSortedIndex', () {
      var list = <int>[];
      int _intCmp(int i1, int i2) => i1 - i2;
      expect(findSortedIndex(list, 1, _intCmp), 0);
      expect(findSortedIndex([1, 2], 1, _intCmp), 0);
      expect(findSortedIndex([0, 2], 1, _intCmp), 1);
      expect(findSortedIndex([0], 1, _intCmp), 1);
      expect(findSortedIndex([1], 0, _intCmp), 0);

      expect(findSortedIndex([2, 4, 6, 8, 10], 1, _intCmp), 0);
      expect(findSortedIndex([2, 4, 6, 8, 10], 3, _intCmp), 1);
      expect(findSortedIndex([2, 4, 6, 8, 10], 5, _intCmp), 2);
      expect(findSortedIndex([2, 4, 6, 8, 10], 7, _intCmp), 3);
      expect(findSortedIndex([2, 4, 6, 8, 10], 9, _intCmp), 4);
      expect(findSortedIndex([2, 4, 6, 8, 10], 11, _intCmp), 5);

      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 1, _intCmp), 0);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 3, _intCmp), 1);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 5, _intCmp), 2);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 7, _intCmp), 3);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 9, _intCmp), 4);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 11, _intCmp), 5);
      expect(findSortedIndex([2, 4, 6, 8, 10, 12], 13, _intCmp), 6);
    });
  });
}
