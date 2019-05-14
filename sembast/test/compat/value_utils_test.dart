library sembast.value_utils_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/utils.dart';
import 'package:sembast/utils/value_utils.dart' as utils;

import 'test_common.dart';

void main() {
  group('value_utils', () {
    test('cloneMap', () {
      var existing = <String, dynamic>{
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      };
      var cloned = utils.cloneMap(existing);
      expect(cloned, existing);
      existing['test'] = 3;
      (existing['nested'] as Map)['sub'] = 4;
      (((existing['nested'] as Map)['list'] as List)[0] as Map)['n'] = 5;
      // Make sure chaging the existing does not change the clone
      expect(existing, {
        'test': 3,
        'nested': {
          'sub': 4,
          'list': [
            {'n': 5},
            2
          ]
        }
      });
      expect(cloned, {
        'test': 1,
        'nested': {
          'sub': 2,
          'list': [
            {'n': 1},
            2
          ]
        }
      });
    });
    test('compare', () {
      expect(compareValue('1', '2'), Comparable.compare('1', '2'));
      expect(compareValue(1, 2), Comparable.compare(1, 2));
      expect(compareValue(1, '2'), isNull);

      // compareValue
      expect(compareValue([0], [0]), 0);
    });

    test('equals', () {
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals(0, 0), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals(0, 1), isFalse);

      // array
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.equals([0], [0]), isTrue);
    });

    test('lessThen', () {
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan(0, 1), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan(0, 0), isFalse);

      // array
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [1]), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [0, 0]), isTrue);
      // ignore: deprecated_member_use, deprecated_member_use_from_same_package
      expect(utils.lessThan([0], [0]), isFalse);
    });
  });
}
