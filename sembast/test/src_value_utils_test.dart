import 'package:sembast/src/value_utils.dart';
import 'package:test/test.dart';

void main() {
  group('src_value_utils', () {
    test('valueAreEquals', () {
      void checkEquals(Object? object1, Object? object2) {
        expect(valueAreEquals(object1, object2), isTrue,
            reason: '$object1 != $object2');
      }

      void checkNotEquals(Object? object1, Object? object2) {
        expect(valueAreEquals(object1, object2), isFalse,
            reason: '$object1 == $object2');
      }

      checkEquals(null, null);
      checkNotEquals(null, 1);
      checkEquals([
        {
          'a': [1]
        }
      ], [
        {
          'a': [1]
        }
      ]);
      checkNotEquals([
        {
          'a': [1]
        }
      ], [
        {
          'a': [2]
        }
      ]);
    });
  });
}
