import 'package:sembast/utils/key_utils.dart';
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
