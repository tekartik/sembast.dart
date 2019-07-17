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
    Database db;

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
    });
  });
}
