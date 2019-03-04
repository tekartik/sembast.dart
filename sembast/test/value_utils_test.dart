library sembast.value_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/utils.dart';
import 'package:sembast/utils/value_utils.dart' as utils;

import 'test_common.dart';

void main() {
  group('value_utils', () {
    test('compare', () {
      expect(compareValue('1', '2'), Comparable.compare('1', '2'));
      expect(compareValue(1, 2), Comparable.compare(1, 2));
      expect(compareValue(1, '2'), isNull);

      // compareValue
      expect(compareValue([0], [0]), 0);
    });

    test('equals', () {
      expect(utils.equals(0, 0), isTrue);
      expect(utils.equals(0, 1), isFalse);

      // array
      expect(utils.equals([0], [0]), isTrue);
    });

    test('lessThen', () {
      expect(utils.lessThan(0, 1), isTrue);
      expect(utils.lessThan(0, 0), isFalse);

      // array
      expect(utils.lessThan([0], [1]), isTrue);
      expect(utils.lessThan([0], [0, 0]), isTrue);
      expect(utils.lessThan([0], [0]), isFalse);
    });
  });
}
