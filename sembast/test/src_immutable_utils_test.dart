import 'package:sembast/src/immutable_utils.dart';
import 'package:test/test.dart';

void main() {
  group('immutable_utils', () {
    test('immutableValue', () {
      expect(immutableValueOrNull(null), null);
      expect(immutableValueOrNull(null), null);
      expect(immutableValue(1), immutableValueOrNull(1));
      expect(immutableValue([1]), immutableValueOrNull([1]));
      expect(immutableValue([null]), [null]);
      expect(immutableValue([1, null, 'test']), [1, null, 'test']);
    });
  });
}
