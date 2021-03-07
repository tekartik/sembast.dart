import 'dart:convert';

import 'package:sembast/src/type_adapter_impl.dart';
import 'package:sembast/src/utils.dart';

class _Encoder extends Converter<Object, Object> {
  final JsonEncodableCodec codec;

  _Encoder(this.codec);

  @override
  Object convert(Object value) =>
      toJsonEncodable(value, codec._adapters!.values);
}

class _Decoder extends Converter<Object, Object> {
  final JsonEncodableCodec codec;

  _Decoder(this.codec);

  @override
  Object convert(Object value) => fromJsonEncodable(value, codec._adapters);
}

/// Never null, convert a list to a map.
Map<String, SembastTypeAdapter> sembastTypeAdaptersToMap(
    Iterable<SembastTypeAdapter>? adapters) {
  var _adapters = <String, SembastTypeAdapter>{};
  if (adapters != null) {
    for (var adapter in adapters) {
      assert(_adapters[adapter.name] == null,
          'Adapter already exists for ${adapter.name}');
      _adapters[adapter.name] = adapter;
    }
  }
  return _adapters;
}

/// Codec to/from a json encodable format, custome types being handled
/// by the type adapters
class JsonEncodableCodec extends Codec<Object, Object> {
  Map<String, SembastTypeAdapter>? _adapters;

  /// Codec with the needed adapters
  JsonEncodableCodec({Iterable<SembastTypeAdapter>? adapters}) {
    _adapters = sembastTypeAdaptersToMap(adapters);
    _decoder = _Decoder(this);
    _encoder = _Encoder(this);
  }

  late _Decoder _decoder;

  @override
  _Decoder get decoder => _decoder;

  late _Encoder _encoder;

  @override
  _Encoder get encoder => _encoder;

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
    var clone;
    map.forEach((key, item) {
      if (!(key is String)) {
        throw ArgumentError.value(key);
      }
      var converted = _toJsonEncodable(item, adapters);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone[key] = converted;
      }
    });
    return clone ?? map;
  } else if (value is List) {
    var list = value;
    var clone;
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
    throw ArgumentError.value(e.invalidValue,
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && !(converted is Map<String, Object?>)) {
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

    var clone;
    map.forEach((key, item) {
      var converted = _fromEncodable(item as Object?, adapters);
      if (!identical(converted, item)) {
        clone ??= Map<String, Object?>.from(map);
        clone[key] = converted;
      }
    });
    return (clone ?? map) as Object;
  } else if (value is List) {
    var list = value;
    var clone;
    for (var i = 0; i < list.length; i++) {
      var item = list[i];
      var converted = _fromEncodable(item as Object?, adapters);
      if (!identical(converted, item)) {
        clone ??= List.from(list);
        clone[i] = converted;
      }
    }
    return (clone ?? list) as Object;
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
        '${e.invalidValue.runtimeType} in $value', 'not supported');
  }

  /// Ensure root is Map<String, Object?> if only Map
  if (converted is Map && !(converted is Map<String, Object?>)) {
    converted = converted.cast<String, Object?>();
  }
  return converted;
}

/// Default jsonEncodableCodec
final sembastDefaultJsonEncodableCodec =
    JsonEncodableCodec(adapters: sembastDefaultTypeAdapters);
