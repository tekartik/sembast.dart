library sembast.value_utils_test;

// basically same as the io runner but with extra output

import 'package:sembast/src/api/protected/key_utils.dart';
// ignore_for_file: implementation_imports
import 'package:test/test.dart';

void main() {
  group('key_utils', () {
    test('api', () {
      // ignore: unnecessary_statements
      generateStringKey;
    });
    test('generateStringKey', () {
      var key = generateStringKey();
      expect(key, isNotEmpty);
      expect(generateStringKey(), isNot(key));
    });
  });
}
