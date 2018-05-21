library sembast.utils_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/utils.dart';

import 'test_common.dart';

void main() {
  group('utils', () {
    test('sanitize_map', () {
      var map = <dynamic, dynamic>{"test": 1};
      Map<String, dynamic> sanitizedMap = sanitizeValue(map);
      expect(sanitizedMap, map);
    });

    test('convert_map', () {});

    test('check_value', () {
      expect(checkValue(new DateTime.now()), isFalse);
      expect(checkValue([new DateTime.now()]), isFalse);
      expect(checkValue({"test": new DateTime.now()}), isFalse);
      expect(checkValue({1: 2}), isFalse);
    });
  });
}
