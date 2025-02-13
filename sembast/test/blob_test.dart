import 'package:sembast/blob.dart';
import 'package:test/test.dart';

import 'test_common.dart';

void main() {
  group('blob', () {
    test('equals', () {
      expect(Blob.fromList([1, 2]), Blob.fromList([1, 2]));
      expect(Blob.fromList([]), Blob.fromList([]));
      expect(Blob.fromList([1, 2]), isNot(Blob.fromList([1, 2, 3])));
      expect(Blob.fromList([1, 2, 3]), isNot(Blob.fromList([1, 2])));
      expect(Blob.fromList([1, 2]), isNot(Blob.fromList([1, 3])));
      expect(Blob.fromList([1, 2]), isNot(Blob.fromList([0, 2])));
    });
    test('compareTo', () {
      expect(Blob.fromList([1, 2]).compareTo(Blob.fromList([1, 2])), 0);
      expect(
        Blob.fromList([1, 2]).compareTo(Blob.fromList([1, 2, 3])),
        lessThan(0),
      );
      expect(
        Blob.fromList([1, 2, 3]).compareTo(Blob.fromList([1, 2])),
        greaterThan(0),
      );
      expect(
        Blob.fromList([1, 2]).compareTo(Blob.fromList([1, 3])),
        lessThan(0),
      );
      expect(
        Blob.fromList([1, 2]).compareTo(Blob.fromList([2, 2])),
        lessThan(0),
      );
      expect(
        Blob.fromList([1, 2]).compareTo(Blob.fromList([1, 1])),
        greaterThan(0),
      );
      expect(
        Blob.fromList([1, 2]).compareTo(Blob.fromList([0, 2])),
        greaterThan(0),
      );
    });
    void checkBlob(Blob blob, String expectedBase64) {
      var reason = '$blob';
      expect(blob.toBase64(), expectedBase64, reason: 'timestamp $reason');
    }

    test('toBase64', () {
      checkBlob(Blob.fromList([0, 0]), 'AAA=');
      checkBlob(Blob.fromList([0, 1]), 'AAE=');
      checkBlob(Blob.fromList([0, 255]), 'AP8=');
      checkBlob(Blob.fromList([0, 256]), 'AAA=');
    });
    test('various', () {
      void testBlob(Blob blob) {
        var other = Blob(blob.bytes);
        expect(other, blob);
        other = Blob.fromBase64(blob.toBase64());
        expect(other, blob);
        other = Blob.fromList(blob.bytes);
        expect(other, blob);
      }

      testBlob(Blob.fromList([]));
      testBlob(Blob.fromList([0]));
      testBlob(Blob.fromList([256]));
    });
  });
}
