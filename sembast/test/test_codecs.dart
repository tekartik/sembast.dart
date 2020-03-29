import 'dart:convert';
import 'dart:math';

class MyJsonEncoder extends Converter<dynamic, String> {
  @override
  String convert(dynamic input) => json.encode(input);
}

class MyJsonDecoder extends Converter<String, dynamic> {
  @override
  dynamic convert(String input) => json.decode(input);
}

class MyJsonCodec extends Codec<dynamic, String> {
  @override
  final decoder = MyJsonDecoder();
  @override
  final encoder = MyJsonEncoder();
}

class MyCustomEncoder extends Converter<dynamic, String> {
  @override
  String convert(dynamic input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class MyCustomDecoder extends Converter<String, dynamic> {
  @override
  dynamic convert(String input) =>
      json.decode(utf8.decode(base64.decode(input)));
}

/// Simple codec that encode in base 64
class MyCustomCodec extends Codec<dynamic, String> {
  @override
  final decoder = MyCustomDecoder();
  @override
  final encoder = MyCustomEncoder();
}

class MyCustomRandomEncoder extends MyCustomEncoder {
  @override
  String convert(dynamic input) {
    if (input is Map) {
      input = Map<String, dynamic>.from(input as Map);
      input['_custom_seed'] = Random().nextInt(1000);
    }
    return super.convert(input);
  }
}

class MyCustomRandomDecoder extends MyCustomDecoder {
  @override
  dynamic convert(String input) {
    var map = super.convert(input);
    if (map is Map) {
      map = Map<String, dynamic>.from(map as Map);
      map.remove('_custom_seed');
    }
    return map;
  }
}

/// Simple codec that encode in base 64 with an added seed
class MyCustomRandomCodec extends Codec<dynamic, String> {
  @override
  final decoder = MyCustomRandomDecoder();
  @override
  final encoder = MyCustomRandomEncoder();
}
