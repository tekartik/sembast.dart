library sembast.type_adapter_test;

import 'package:sembast/blob.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/timestamp_impl.dart';
import 'package:sembast/src/type_adapter_impl.dart';

import 'test_common.dart';

void main() {
  group('json_encodable_codec', () {
    var codec = JsonEncodableCodec(adapters: [sembastTimestampAdapter]);
    group('encode', () {
      test('map', () {
        expect(codec.encode(<dynamic, dynamic>{'test': Timestamp(1, 2)}),
            const TypeMatcher<Map<String, dynamic>>());
        expect(codec.encode(<dynamic, dynamic>{'test': 1}),
            const TypeMatcher<Map<String, dynamic>>());
      });
      test('custom', () {
        expect(codec.encode(Timestamp(1, 2)),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z'});
      });
      test('custom in list', () {
        expect(codec.encode([Timestamp(1, 2)]), [
          {'@Timestamp': '1970-01-01T00:00:01.000000002Z'}
        ]);
      });
      test('look like custom', () {
        expect(codec.encode({'@Timestamp': '1970-01-01T00:00:01.000000002Z'}), {
          '@': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'}
        });
        expect(
            codec.encode({
              '@Timestamp': '1970-01-01T00:00:01.000000002Z',
              'other': 'dummy'
            }),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z', 'other': 'dummy'});
        expect(codec.encode({'@': 1}), {
          '@': {'@': 1}
        });
        // fail to encode
        expect(codec.encode({'@': Timestamp(1, 2)}), {
          '@': {'@': Timestamp(1, 2)}
        });
      });
    });
    group('decode', () {
      test('custom', () {
        expect(codec.decode({'@Timestamp': '1970-01-01T00:00:01.000000002Z'}),
            Timestamp(1, 2));
      });
      test('not_custom', () {
        expect(
            codec.decode({
              '@Timestamp': '1970-01-01T00:00:01.000000002Z',
              'other': 'dummy'
            }),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z', 'other': 'dummy'});
      });
      test('look like custom', () {
        expect(
            codec.decode({
              '@': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'}
            }),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z'});
      });
    });
    test('all', () {
      var codec = JsonEncodableCodec(adapters: [sembastTimestampAdapter]);
      void _loop(dynamic decoded) {
        var encoded = codec.encode(decoded);
        try {
          expect(codec.decode(encoded), decoded);
        } catch (e) {
          print('checking value $decoded $encoded');
          rethrow;
        }
      }

      for (var value in [
        null,
        true,
        1,
        2.0,
        'text',
        {'test': 'value1'},
        ['value1, value2'],
        Timestamp(1, 2),
        {'@Timestamp': '1970-01-01T00:00:01.000000002Z'},
        {
          'nested': [
            Timestamp(2, 3),
            [
              {'sub': 1},
              {'subcustom': Timestamp(2, 3)},
            ]
          ]
        },
      ]) {
        _loop(value);
      }
    });

    test('allAdapters', () {
      var codec = JsonEncodableCodec(
          adapters: ([
        sembastDateTimeAdapter,
        sembastBlobAdapter,
        sembastTimestampAdapter
      ]));
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
        'looksLikeBlob': {'@Blob': 'AQID'},
        'looksLikeDummy': {'@': null}
      };
      var encoded = {
        'null': null,
        'int': 1,
        'listList': [1, 2, 3],
        'string': 'text',
        'dateTime': {'@DateTime': '1970-01-01T00:00:00.001Z'},
        'timestamp': {'@Timestamp': '1970-01-01T00:00:00.000001Z'},
        'blob': {'@Blob': 'AQID'},
        'looksLikeDateTime': {
          '@': {'@DateTime': '1970-01-01T00:00:00.001Z'}
        },
        'looksLikeTimestamp': {
          '@': {'@Timestamp': '1970-01-01T00:00:00.000001Z'}
        },
        'looksLikeBlob': {
          '@': {'@Blob': 'AQID'}
        },
        'looksLikeDummy': {
          '@': {'@': null}
        }
      };
      expect(codec.encode(decoded), encoded);
    });
  });
}
