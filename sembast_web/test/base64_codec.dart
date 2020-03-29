import 'dart:convert';

class SembaseBase64Encoder extends Converter<dynamic, String> {
  @override
  String convert(dynamic input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class SembaseBase64Decoder extends Converter<String, dynamic> {
  @override
  dynamic convert(String input) =>
      json.decode(utf8.decode(base64.decode(input)));
}

/// Simple codec that encode in base 64
class SembaseBase64Codec extends Codec<dynamic, String> {
  @override
  final decoder = SembaseBase64Decoder();
  @override
  final encoder = SembaseBase64Encoder();
}
