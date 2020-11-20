library sembast.json_encodable_codec_test;

import 'package:sembast/blob.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/timestamp_impl.dart';
import 'package:sembast/src/type_adapter_impl.dart';

import 'test_common.dart';

class _Dummy {}

void main() {
  group('json_encodable_codec', () {
    var codec = JsonEncodableCodec(adapters: [sembastTimestampAdapter]);
    group('encode', () {
      test('map', () {
        expect(codec.encode(<dynamic, dynamic>{'test': Timestamp(1, 2)}),
            const TypeMatcher<Map<String, Object? >>());
        expect(codec.encode(<dynamic, dynamic>{'test': 1}),
            const TypeMatcher<Map<String, Object? >>());
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

    test('modified', () {
      var map = {};
      expect(identical(map, map), isTrue);

      var codec = JsonEncodableCodec(adapters: [sembastTimestampAdapter]);
      var identicals = [
        <String, Object? >{},
        1,
        2.5,
        'text',
        true,
        null,
        //<dynamic, dynamic>{},
        [],
        [
          {
            'test': [
              1,
              true,
              [4.5]
            ]
          }
        ],
        <String, Object? >{
          'test': [
            1,
            true,
            [4.5]
          ]
        }
      ];
      for (var value in identicals) {
        var encoded = value;
        encoded = codec.encode(value);
        expect(codec.decode(encoded), value);
        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
      var notIdenticals = [
        <dynamic, dynamic>{}, // being cast
        Timestamp(1, 2),
        [Timestamp(1, 2)],
        <String, Object? >{'test': Timestamp(1, 2)},
        <String, Object? >{
          'test': [Timestamp(1, 2)]
        }
      ];
      for (var value in notIdenticals) {
        Object? encoded = value;
        encoded = codec.encode(value);
        expect(codec.decode(encoded), value);
        expect(!identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
    });
  });
  group('json_encodable', () {
    var adapters = sembastDefaultTypeAdapters;
    var adaptersMap = sembastTypeAdaptersToMap(adapters);
    test('timestamp', () {
      expect(toJsonEncodable(Timestamp(1, 2), adapters),
          {'@Timestamp': '1970-01-01T00:00:01.000000002Z'});
    });
    test('dateTime', () {
      try {
        expect(
            toJsonEncodable(DateTime.fromMillisecondsSinceEpoch(1), adapters),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z'});
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('dummy type', () {
      // Make sure it talks about the field and the type
      try {
        toJsonEncodable({'dummy': _Dummy()}, adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('_Dummy'));
        expect(e.toString(), contains('dummy'));
      }
      try {
        toJsonEncodable(_Dummy(), adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('_Dummy'));
      }
      try {
        toJsonEncodable([_Dummy()], adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        expect(e.toString(), contains('_Dummy'));
      }
    });

    test('null key', () {
      try {
        toJsonEncodable({null: 1}, adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        // Invalid argument (Null in {null: 1}): not supported: null
        expect(e.toString(), contains('Null'));
      }
      try {
        toJsonEncodable({'test': 2, null: 1}, adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        // Invalid argument (Null in {test: 2, null: 1}): not supported: null
        expect(e.toString(), contains('Null'));
      }
    });

    test('invalid key', () {
      try {
        toJsonEncodable({1: 1}, adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        // Invalid argument (int in {1: 1}): not supported: 1
        expect(e.toString(), contains('int'));
      }
      try {
        toJsonEncodable({'test': 2, 1: 1}, adapters);
        fail('should fail');
      } on ArgumentError catch (e) {
        // Invalid argument (int in {test: 2, 1: 1}): not supported: 1
        expect(e.toString(), contains('int'));
      }
    });

    test('FieldValue', () {
      try {
        expect(toJsonEncodable(FieldValue.delete, adapters),
            {'@Timestamp': '1970-01-01T00:00:01.000000002Z'});
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('Dummy', () {
      expect(fromJsonEncodable({'@Dummy': 'test'}, adaptersMap),
          {'@Dummy': 'test'});
      expect(toJsonEncodable({'@Dummy': 'test'}, adapters), {
        '@': {'@Dummy': 'test'}
      });
      expect(toJsonEncodable({'@Dummy': 'test', 'other': 1}, adapters),
          {'@Dummy': 'test', 'other': 1});
    });

    test('allAdapters', () {
      var decoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'timestamp': Timestamp(1, 2),
        'blob': Blob.fromList([1, 2, 3]),
        '@Dummy': 'test',
        'dummy': {'@Dummy': 'test'},
        'dummyMap': {'@': 'test'}
      };
      var encoded = {
        'null': null,
        'bool': true,
        'int': 1,
        'list': [1, 2, 3],
        'map': {
          'sub': [1, 2, 3]
        },
        'string': 'text',
        'timestamp': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'},
        'blob': {'@Blob': 'AQID'},
        '@Dummy': 'test',
        'dummy': {
          '@': {'@Dummy': 'test'}
        },
        'dummyMap': {
          '@': {'@': 'test'}
        }
      };
      expect(toJsonEncodable(decoded, adapters), encoded);
      expect(fromJsonEncodable(encoded, adaptersMap), decoded);
    });

    test('modified', () {
      var identicals = [
        <String, Object? >{},
        1,
        2.5,
        'text',
        true,
        null,
        //<dynamic, dynamic>{},
        [],
        [
          {
            'test': [
              1,
              true,
              [4.5]
            ]
          }
        ],
        <String, Object? >{
          'test': [
            1,
            true,
            [4.5]
          ]
        }
      ];
      for (var value in identicals) {
        var encoded = toJsonEncodable(value, adapters);

        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
        value = fromJsonEncodable(value, adaptersMap);
        expect(identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
      var notIdenticals = [
        <dynamic, dynamic>{}, // being cast
        Blob.fromList([1, 2, 3]),
        Timestamp(1, 2),
        [Timestamp(1, 2)],
        <String, Object? >{'test': Timestamp(1, 2)},
        <String, Object? >{
          'test': [Timestamp(1, 2)]
        },
        [
          {'test': Timestamp(1, 2)}
        ],
        {'@Dummy': 'test'}
      ];
      for (var value in notIdenticals) {
        Object? encoded = value;
        encoded = toJsonEncodable(value, adapters);

        expect(fromJsonEncodable(encoded, adaptersMap), value);
        expect(!identical(encoded, value), isTrue,
            reason:
                '$value ${identityHashCode(value)} vs ${identityHashCode(encoded)}');
      }
    });
  });
}
