import 'dart:convert';

import 'package:sembast/src/type_adapter_impl.dart';
import 'package:sembast/src/utils.dart';

/// Encoder.
class JsonEncodableEncoder extends Converter<Object, Object> {
  final JsonEncodableCodec _codec;

  /// Encoder.
  JsonEncodableEncoder(this._codec);

  @override
  Object convert(Object input) =>
      toJsonEncodable(input, _codec._adapters!.values);
}

/// Decoder.
class JsonEncodableDecoder extends Converter<Object, Object> {
  final JsonEncodableCodec _codec;

  /// Decoder.
  JsonEncodableDecoder(this._codec);

  @override
  Object convert(Object input) => fromJsonEncodable(input, _codec._adapters);
}

/// Never null, convert a list to a map.
Map<String, SembastTypeAdapter> sembastTypeAdaptersToMap(
    Iterable<SembastTypeAdapter>? adapters) {
  var adaptersMap = <String, SembastTypeAdapter>{};
  if (adapters != null) {
    for (var adapter in adapters) {
      assert(adaptersMap[adapter.name] == null,
          'Adapter already exists for ${adapter.name}');
      adaptersMap[adapter.name] = adapter;
    }
  }
  return adaptersMap;
}

/// Codec to/from a json encodable format, custome types being handled
/// by the type adapters
class JsonEncodableCodec extends Codec<Object, Object> {
  Map<String, SembastTypeAdapter>? _adapters;

  /// Codec with the needed adapters
  JsonEncodableCodec({Iterable<SembastTypeAdapter>? adapters}) {
    _adapters = sembastTypeAdaptersToMap(adapters);
    _decoder = JsonEncodableDecoder(this);
    _encoder = JsonEncodableEncoder(this);
  }

  late JsonEncodableDecoder _decoder;

  @override
  JsonEncodableDecoder get decoder => _decoder;

  late JsonEncodableEncoder _encoder;

  @override
  JsonEncodableEncoder get encoder => _encoder;

  /// True if the value is one of the supported adapter types.
  bool supportsType(dynamic value) {
    if (_adapters != null) {
      for (var adapter in _adapters!.values) {
        if (adapter.isType(value)) {
          return true;
        }
      }
    }
    return false;
  }
}

// Look like custom?
bool _looksLikeCustomType(Map map) {
  if (map.length == 1) {
    var key = map.keys.first;
    if (key is String) {
      return key.startsWith('@');
    }
    throw ArgumentError.value(key);
  }
  return false;
}

dynamic _toJsonEncodable(dynamic value, Iterable<SembastTypeAdapter> adapters) {
  if (isBasicTypeOrNull(value)) {
    return value;
  }
  // handle adapters
  for (var adapter in adapters) {
    if (adapter.isType(value)) {
      return <String, Object?>{'@${adapter.name}': adapter.encode(value)};
    }
  }

  if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      return <String, Object?>{'@': map};
    }
    Map<String, Object?>? clone;
    map.forEach((key, item) {
      if (key is! String) {
        throw ArgumentError.value(key);
      }
      var converted = _toJsonEncodable(item, adapters);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone![key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    List? clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _toJsonEncodable(item, adapters);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a sembast value to a json encodable value
Object toJsonEncodable(Object value, Iterable<SembastTypeAdapter> adapters) {
  Object? converted;
  try {
    converted = _toJsonEncodable(value, adapters);
  } on ArgumentError catch (e) {
    throw ArgumentError.value(
        e.invalidValue,
        '${(e.invalidValue as Object?).runtimeType} in $value',
        'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && converted is! Map<String, Object?>) {
    converted = converted.cast<String, Object?>();
  }
  return converted!;
}

Object? _fromEncodable(
    Object? value, Map<String, SembastTypeAdapter>? adapters) {
  if (isBasicTypeOrNull(value)) {
    return value;
  } else if (value is Map) {
    var map = value;
    if (_looksLikeCustomType(map)) {
      var type = (map.keys.first as String).substring(1);
      if (type == '') {
        return map.values.first as Object;
      }
      var adapter = adapters![type];
      if (adapter != null) {
        var encodedValue = value.values.first;
        try {
          return adapter.decode(encodedValue) as Object;
        } catch (e) {
          print('$e - ignoring $encodedValue ${encodedValue.runtimeType}');
        }
      }
    }

    Map<String, Object?>? clone;
    map.forEach((key, item) {
      var converted = _fromEncodable(item as Object?, adapters);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone![key.toString()] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    List? clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _fromEncodable(item as Object?, adapters);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return clone ?? list;
  } else {
    throw ArgumentError.value(value);
  }
}

/// Convert a value from a Sqflite value
Object fromJsonEncodable(
    Object value, Map<String, SembastTypeAdapter>? adapters) {
  Object converted;
  try {
    converted = _fromEncodable(value, adapters)!;
  } on ArgumentError catch (e) {
    throw ArgumentError.value(e.invalidValue,
        '${(e.invalidValue as Object).runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && converted is! Map<String, Object?>) {
    converted = converted.cast<String, Object?>();
  }
  return converted;
}

/// Default jsonEncodableCodec
final sembastDefaultJsonEncodableCodec =
    JsonEncodableCodec(adapters: sembastDefaultTypeAdapters);
