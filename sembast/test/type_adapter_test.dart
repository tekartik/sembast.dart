library sembast.type_adapter_test;

import 'dart:convert';

import 'package:sembast/blob.dart';
import 'package:sembast/src/timestamp_impl.dart';
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
    test('timestamp', () {
      expect(
          sembastTimestampAdapter
              .encode(Timestamp.fromMillisecondsSinceEpoch(1)),
          '1970-01-01T00:00:00.001Z');

      expect(
          sembastTimestampAdapter
              .encode(Timestamp.fromMicrosecondsSinceEpoch(1)),
          '1970-01-01T00:00:00.000001Z');

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
    test('defaultEncoder', () {
      var sembastCodec = defaultSembastCodec;
      var decoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'timestamp': Timestamp.fromMicrosecondsSinceEpoch(1),
        'blob': Blob.fromList([1, 2, 3]),
      };
      var encoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'timestamp': {'@Timestamp': '1970-01-01T00:00:00.000001Z'},
        'blob': {'@Blob': 'AQID'}
      };

      expect(jsonDecode(sembastCodec.codec.encode(decoded)), encoded);
      expect(sembastCodec.codec.decode(jsonEncode(encoded)), decoded);
    });
    test('allAdapters', () {
      var sembastCodec = sembastCodecWithAdapters([
        sembastDateTimeAdapter,
        sembastBlobAdapter,
        sembastTimestampAdapter
      ]);
      var decoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'dateTime': DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
        'timestamp': Timestamp.fromMicrosecondsSinceEpoch(1),
        'blob': Blob.fromList([1, 2, 3]),
        'looksLikeDateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'looksLikeTimestamp': {'@Timestamp': '1970-01-01T00:00:00.000001Z'},
        'looksLikeBlob': {'@Blob': 'AQID'}
      };
      var encoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'dateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'timestamp': {'@Timestamp': '1970-01-01T00:00:00.000001Z'},
        'blob': {'@Blob': 'AQID'},
        'looksLikeDateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'looksLikeTimestamp': {'@Timestamp': '1970-01-01T00:00:00.000001Z'},
        'looksLikeBlob': {'@Blob': 'AQID'}
      };

      expect(jsonDecode(sembastCodec.codec.encode(decoded)), encoded);
      expect(
          sembastCodec.codec.decode(jsonEncode(encoded)),
          decoded
            ..['looksLikeDateTime'] =
                DateTime.fromMillisecondsSinceEpoch(1, isUtc: true)
            ..['looksLikeTimestamp'] = Timestamp.fromMicrosecondsSinceEpoch(1)
            ..['looksLikeBlob'] = Blob.fromList([1, 2, 3]));

      // Empty blob
      decoded = {
        'blob': Blob.fromList([]),
      };
      encoded = {
        'blob': {'@Blob': ''}
      };
      expect(jsonDecode(sembastCodec.codec.encode(decoded)), encoded);
      expect(sembastCodec.codec.decode(jsonEncode(encoded)), decoded);

      // Bad format
      encoded = {
        'dateTime': {'@DateTime': 'dummy'},
        'blob': {'@Blob': 'dummy'}
      };

      expect(sembastCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {'@DateTime': 'dummy'},
        'blob': {'@Blob': 'dummy'}
      });

      // Bad type
      encoded = {
        'dateTime': {'@DateTime': 1},
        'blob': {'@Blob': 1}
      };

      expect(sembastCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {'@DateTime': 1},
        'blob': {'@Blob': 1}
      });

      // Null value
      encoded = {
        'dateTime': {'@DateTime': null},
        'blob': {'@Blob': null}
      };

      expect(sembastCodec.codec.decode(jsonEncode(encoded)), {
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

      expect(sembastCodec.codec.decode(jsonEncode(encoded)), {
        'dateTime': {
          '@DateTime': {
            'blob': Blob.fromList([1, 2, 3])
          },
        }
      });
    });
  });
}
