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
  });
}
