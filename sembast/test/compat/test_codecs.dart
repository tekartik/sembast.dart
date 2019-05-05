import 'dart:convert';
import 'dart:math';

class MyJsonEncoder extends Converter<Map<String, dynamic>, String> {
  @override
  String convert(Map<String, dynamic> input) => json.encode(input);
}

class MyJsonDecoder extends Converter<String, Map<String, dynamic>> {
  @override
  Map<String, dynamic> convert(String input) {
    var result = json.decode(input);
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

class MyJsonCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyJsonDecoder();
  @override
  final encoder = MyJsonEncoder();
}

class MyCustomEncoder extends Converter<Map<String, dynamic>, String> {
  @override
  String convert(Map<String, dynamic> input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class MyCustomDecoder extends Converter<String, Map<String, dynamic>> {
  @override
  Map<String, dynamic> convert(String input) {
    var result = json.decode(utf8.decode(base64.decode(input)));
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

/// Simple codec that encode in base 64
class MyCustomCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyCustomDecoder();
  @override
  final encoder = MyCustomEncoder();
}

class MyCustomRandomEncoder extends MyCustomEncoder {
  @override
  String convert(Map<String, dynamic> input) {
    if (input != null) {
      input = Map<String, dynamic>.from(input);
      input['_custom_seed'] = Random().nextInt(1000);
    }
    return super.convert(input);
  }
}

class MyCustomRandomDecoder extends MyCustomDecoder {
  @override
  Map<String, dynamic> convert(String input) {
    var map = super.convert(input);
    if (map is Map) {
      map = Map<String, dynamic>.from(map);
      map.remove('_custom_seed');
    }
    return map;
  }
}

/// Simple codec that encode in base 64 with an added seed
class MyCustomRandomCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyCustomRandomDecoder();
  @override
  final encoder = MyCustomRandomEncoder();
}
