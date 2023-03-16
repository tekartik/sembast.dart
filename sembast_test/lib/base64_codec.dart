import 'dart:convert';

import 'package:sembast/sembast.dart';

class SembastBase64Encoder extends Converter<Object?, String> {
  @override
  String convert(dynamic input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class SembastBase64Decoder extends Converter<String, Object?> {
  @override
  dynamic convert(String input) =>
      json.decode(utf8.decode(base64.decode(input)));
}

/// Simple codec that encode in base 64
class SembastBase64Codec extends Codec<Object?, String> {
  @override
  final Converter<String, Object?> decoder = SembastBase64Decoder();
  @override
  final Converter<Object?, String> encoder = SembastBase64Encoder();
}

class SembastBase64CodecAsync extends AsyncContentCodecBase {
  final impl = SembastBase64Codec();
  @override
  Future<Object?> decodeAsync(String encoded) async {
    return impl.decode(encoded);
  }

  @override
  Future<String> encodeAsync(Object? input) async {
    return impl.encode(input);
  }
}
