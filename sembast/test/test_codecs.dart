import 'dart:convert';
import 'dart:math';

class MyJsonEncoder extends Converter<Object?, String> {
  @override
  String convert(dynamic input) => json.encode(input);
}

class MyJsonDecoder extends Converter<String, Object> {
  @override
  Object convert(String input) => json.decode(input) as Object;
}

class MyJsonCodec extends Codec<Object?, String> {
  @override
  final Converter<String, Object> decoder = MyJsonDecoder();
  @override
  final Converter<Object?, String> encoder = MyJsonEncoder();
}

class MyCustomEncoder extends Converter<Object?, String> {
  @override
  String convert(dynamic input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class MyCustomDecoder extends Converter<String, Object> {
  @override
  Object convert(String input) =>
      json.decode(utf8.decode(base64.decode(input))) as Object;
}

/// Simple codec that encode in base 64
class MyCustomCodec extends Codec<Object?, String> {
  @override
  final Converter<String, Object> decoder = MyCustomDecoder();
  @override
  final Converter<Object?, String> encoder = MyCustomEncoder();
}

class MyCustomRandomEncoder extends MyCustomEncoder {
  @override
  String convert(dynamic input) {
    if (input is Map) {
      input = Map<String, Object?>.from(input);
      input['_custom_seed'] = Random().nextInt(1000);
    }
    return super.convert(input);
  }
}

class MyCustomRandomDecoder extends MyCustomDecoder {
  @override
  Object convert(String input) {
    var map = super.convert(input);
    if (map is Map) {
      map = Map<String, Object?>.from(map);
      map.remove('_custom_seed');
    }
    return map;
  }
}

/// Simple codec that encode in base 64 with an added seed
class MyCustomRandomCodec extends Codec<Object?, String> {
  @override
  final Converter<String, Object> decoder = MyCustomRandomDecoder();
  @override
  final Converter<Object?, String> encoder = MyCustomRandomEncoder();
}
