import 'package:sembast/blob.dart';
import 'package:sembast/src/sembast_codec.dart';
import 'package:sembast/timestamp.dart';
import 'package:test/test.dart';

import 'test_codecs.dart';

Future<void> main() async {
  group('sembast_codec', () {
    group('content_codec', () {
      test('json', () {
        var codec = MyJsonCodec();
        expect(codec.encode(null), 'null');
        expect(codec.encode(1), '1');
        expect(codec.encode('1'), '"1"');
      });
    });

    group('sembastCodecDefaultV2', () {
      var jsonEncodableCodec = sembastCodecDefaultV2.jsonEncodableCodec;

      test('encode uses \$ prefix and camelCase names', () {
        expect(jsonEncodableCodec.encode(Timestamp(1, 2)), {
          r'$timestamp': '1970-01-01T00:00:01.000000002Z',
        });
        expect(jsonEncodableCodec.encode(Blob.fromList([1, 2, 3])), {
          r'$blob': 'AQID',
        });
      });

      test('decode reads its own \$ format', () {
        expect(
          jsonEncodableCodec.decode({
            r'$timestamp': '1970-01-01T00:00:01.000000002Z',
          }),
          Timestamp(1, 2),
        );
        expect(
          jsonEncodableCodec.decode({r'$blob': 'AQID'}),
          Blob.fromList([1, 2, 3]),
        );
      });

      test('does not decode the legacy @ format', () {
        expect(
          jsonEncodableCodec.decode({
            '@Timestamp': '1970-01-01T00:00:01.000000002Z',
          }),
          {'@Timestamp': '1970-01-01T00:00:01.000000002Z'},
        );
      });

      test('never writes the legacy @ format', () {
        var encoded = jsonEncodableCodec.encode(Timestamp(1, 2)) as Map;
        expect(encoded.keys, isNot(contains('@Timestamp')));
      });

      test('round trips nested values', () {
        var decoded = {
          'timestamp': Timestamp(1, 2),
          'list': [
            Blob.fromList([1, 2, 3]),
          ],
        };
        var encoded = jsonEncodableCodec.encode(decoded);
        expect(encoded, {
          'timestamp': {r'$timestamp': '1970-01-01T00:00:01.000000002Z'},
          'list': [
            {r'$blob': 'AQID'},
          ],
        });
        expect(jsonEncodableCodec.decode(encoded), decoded);
      });
    });
  });
}
