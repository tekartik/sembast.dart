import 'package:sembast/src/async_content_codec.dart';

import 'test_codecs.dart';
import 'test_common.dart';

/// Check that AsyncContentCodecBase is sufficient.
// ignore: unused_element
class _MockAsyncCodec extends AsyncContentCodecBase {
  @override
  Future<Object?> decodeAsync(String encoded) {
    throw UnimplementedError();
  }

  @override
  Future<String> encodeAsync(Object? input) {
    throw UnimplementedError();
  }
}

void main() {
  group('async_content_codec', () {
    var codecSync = MyJsonCodec();
    var codecAsync = AsyncContentJsonCodec();

    test('sembast_codec', () {
      var sembastCodecSync = SembastCodec(signature: 'sync', codec: codecSync);
      expect(sembastCodecSync.hasAsyncCodec, isFalse);
      var sembastCodecAsync =
          SembastCodec(signature: 'sync', codec: codecAsync);
      expect(sembastCodecAsync.hasAsyncCodec, isTrue);
    });
    test('json', () async {
      for (var value in [
        // ignore: inference_failure_on_collection_literal
        {},
        {'blue': 'hotel'}
      ]) {
        var encoded = codecSync.encode(value);
        expect(codecSync.encode(value), encoded);
        expect(() => codecAsync.encode(value), throwsUnsupportedError);
        expect(await codecAsync.encodeAsync(value), encoded);
        expect(codecSync.decode(encoded), value);
        expect(() => codecAsync.decode(encoded), throwsUnsupportedError);
        expect(await codecAsync.decodeAsync(encoded), value);
      }
    });
  });
}
