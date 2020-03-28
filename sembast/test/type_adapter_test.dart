library sembast.type_adapter_test;

import 'dart:convert';

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
      expect(sembastBlobAdapter.encode(Blob.fromList([1, 2, 3])), 'AQID');

      expect(sembastBlobAdapter.decode('AQID'), Blob.fromList([1, 2, 3]));
      expect(sembastBlobAdapter.decode('AQID'), const TypeMatcher<Blob>());

      expect(Blob.fromList([1, 2, 3]), Blob.fromList([1, 2, 3]));
    });
    test('extendedEncoder', () {
      var decoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'dateTime': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        'blob': Blob.fromList([1, 2, 3]),
      };
      var encoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'dateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'blob': {'@Blob': 'AQID'}
      };

      expect(jsonDecode(sembastExtendedCodec.codec.encode(decoded)), encoded);
      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), decoded);

      // Empty blob
      decoded = {
        'blob': Blob.fromList([]),
      };
      encoded = {
        'blob': {'@Blob': ''}
      };
      expect(jsonDecode(sembastExtendedCodec.codec.encode(decoded)), encoded);
      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), decoded);

      // Null blob
      decoded = {
        'blob': Blob(null),
      };
      try {
        expect(jsonDecode(sembastExtendedCodec.codec.encode(decoded)), encoded);
        fail('should fail');
      } on JsonUnsupportedObjectError catch (e) {}

      // Bad format
      encoded = {
        'dateTime': {'@DateTime': 'dummy'},
        'blob': {'@Blob': 'dummy'}
      };

      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {'@DateTime': 'dummy'},
        'blob': {'@Blob': 'dummy'}
      });

      // Bad type
      encoded = {
        'dateTime': {'@DateTime': 1},
        'blob': {'@Blob': 1}
      };

      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {'@DateTime': 1},
        'blob': {'@Blob': 1}
      });

      // Null value
      encoded = {
        'dateTime': {'@DateTime': null},
        'blob': {'@Blob': null}
      };

      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {'@DateTime': null},
        'blob': {'@Blob': null}
      });

      // Nested
      encoded = {
        'dateTime': {
          '@DateTime': {
            'blob': {'@Blob': 'AQID'}
          },
        }
      };

      expect(sembastExtendedCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {
          '@DateTime': {
            'blob': Blob.fromList([1, 2, 3])
          },
        }
      });
    });
  });
}
