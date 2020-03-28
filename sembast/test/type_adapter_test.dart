library sembast.key_test;

// basically same as the io runner but with extra output
import 'dart:typed_data';

import 'package:sembast/src/type_adapter_impl.dart';

import 'test_common.dart';

void main() {
  group('type_adapter', () {
    test('dateTime', () {
      expect(
          sembastDateTimeAdapter
              .encode(DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)),
          '1970-01-01T00:00:00.001Z');
      if (isWeb) {
        expect(
            sembastDateTimeAdapter
                .encode(DateTime.fromMicrosecondsSinceEpoch(1, isUtc: true)),
            '1970-01-01T00:00:00.000Z');
      } else {
        expect(
            sembastDateTimeAdapter
                .encode(DateTime.fromMicrosecondsSinceEpoch(1, isUtc: true)),
            '1970-01-01T00:00:00.000001Z');
      }
      expect(sembastDateTimeAdapter.decode('1970-01-01T00:00:00.000001Z'),
          DateTime.fromMicrosecondsSinceEpoch(1, isUtc: true));
      expect(sembastDateTimeAdapter.decode('1970-01-01T00:00:00.001Z'),
          DateTime.fromMillisecondsSinceEpoch(1, isUtc: true));
    });
    test('blob', () {
      expect(sembastBlobAdapter.encode(Uint8List.fromList([1, 2, 3])), 'AQID');

      expect(sembastBlobAdapter.decode('AQID'), [1, 2, 3]);
      expect(sembastBlobAdapter.decode('AQID'), const TypeMatcher<Uint8List>());
    });
  });
}
