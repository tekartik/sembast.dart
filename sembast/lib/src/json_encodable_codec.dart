import 'dart:convert';

import 'package:sembast/src/type_adapter_impl.dart';
import 'package:sembast/src/utils.dart';

String _decodeType(String typeKey) {
  if (typeKey.startsWith('@')) {
    return typeKey.substring(1);
  }
  return null;
}

class _EncodeState {
  bool changed;
  dynamic encodable;

  @override
  String toString() => '($changed) $encodable';
}

class _Encoder extends Converter<dynamic, dynamic> {
  final JsonEncodableCodec codec;

  _Encoder(this.codec);

  dynamic _toEncodableOrNull(dynamic decoded) {
    for (var entry in codec._adapters.entries) {
      var adapter = entry.value;
      if (adapter.isType(decoded)) {
        return <String, dynamic>{'@${adapter.name}': adapter.encode(decoded)};
      }
    }
    return null;
  }

  @override
  dynamic convert(dynamic value) {
    var state = _EncodeState();
    _toEncodable(state, value);
    // Map Root must be of type <String, dynamic> for compatibility
    var result = state.encodable;
    if (result is Map && !(result is Map<String, dynamic>)) {
      result = result.cast<String, dynamic>();
    }
    return result;
  }

  void _toMapEncodable(_EncodeState state, Map map) {
    Map clone;

    // Look like custom?
    if (map.length == 1 && (map.keys.first as String).startsWith('@')) {
      // Create wrapper to allow proper decoding as a map, not an object
      clone = <String, dynamic>{'@': map};
    } else {
      map.forEach((key, value) {
        _toEncodable(state, value);
        if (state.changed) {
          clone ??= Map<String, dynamic>.from(map);
          clone[key] = state.encodable;
        }
      });
    }
    state.changed = clone != null;
    state.encodable = clone ?? map;
  }

  void _toListEncodable(_EncodeState state, List list) {
    List clone;
    for (var i = 0; i < list.length; i++) {
      var value = list[i];
      _toEncodable(state, value);
      if (state.changed) {
        clone ??= List.from(list);
        clone[i] = state.encodable;
      }
    }
    state.changed = clone != null;
    state.encodable = clone ?? list;
  }

  void _toEncodable(_EncodeState state, dynamic value) {
    if (isBasicTypeFieldValueOrNull(value)) {
      state.changed = false;
      state.encodable = value;
      return;
    } else if (value is Map) {
      _toMapEncodable(state, value);
      return;
    } else if (value is List) {
      _toListEncodable(state, value);
      return;
    }
    var encodable = _toEncodableOrNull(value);
    if (encodable == null) {
      state.changed = false;
      state.encodable = value;
    } else {
      state.encodable = encodable;
      state.changed = true;
    }
  }

  dynamic toEncodable(dynamic value) {
    var state = _EncodeState();
    _toEncodable(state, value);
    return state.encodable;
  }
}

class _JsonDecodeState {
  bool changed;
  dynamic decoded;
  @override
  String toString() => '($changed) $decoded';
}

class _Decoder extends Converter<dynamic, dynamic> {
  final JsonEncodableCodec codec;

  _Decoder(this.codec);

  dynamic _reviverOrNull(Object key, Object value) {
    // Handle special @ key to key the object as is
    if (value is Map && value.length == 1) {
      var type = _decodeType(value.keys.first as String);
      var adapter = codec._adapters[type];
      if (adapter != null) {
        var encodedValue = value.values.first;
        try {
          return adapter.decode(encodedValue);
        } catch (e) {
          print('$e - ignoring $encodedValue ${encodedValue.runtimeType}');
        }
      }
    }
    return null;
  }

  @override
  dynamic convert(dynamic value) {
    var state = _JsonDecodeState();
    _fromEncodable(state, null, value);
    return state.decoded;
  }

  void _fromMapEncodable(_JsonDecodeState state, String key, Map map) {
    var reviver = _reviverOrNull(key, map);
    if (reviver != null) {
      state.changed = true;
      state.decoded = reviver;
    } else {
      // Non encoded
      if (map.length == 1 && map.keys.first == '@') {
        state.changed = true;
        state.decoded = map.values.first;
      } else {
        Map clone;
        map.forEach((key, value) {
          _fromEncodable(state, key as String, value);
          if (state.changed) {
            clone ??= Map<String, dynamic>.from(map);
            clone[key] = state.decoded;
          }
        });
        state.changed = clone != null;
        state.decoded = clone ?? map;
      }
    }
  }

  void _fromListEncodable(_JsonDecodeState state, List list) {
    List clone;
    for (var i = 0; i < list.length; i++) {
      var value = list[i];
      _fromEncodable(state, null, value);
      if (state.changed) {
        clone ??= List.from(list);
        clone[i] = state.decoded;
      }
    }
    state.changed = clone != null;
    state.decoded = clone ?? list;
  }

  void _fromEncodable(_JsonDecodeState state, String key, dynamic value) {
    if (isBasicTypeFieldValueOrNull(value)) {
      state.changed = false;
      state.decoded = value;
      return;
    } else if (value is Map) {
      _fromMapEncodable(state, key, value);
      return;
    } else if (value is List) {
      _fromListEncodable(state, value);
      return;
    }
    throw FormatException(
        'invalid encodable value: $value (${value.runtimeType})');
  }
}

/// Codec to/from a json encodable format, custome types being handled
/// by the type adapters
class JsonEncodableCodec extends Codec<dynamic, dynamic> {
  final _adapters = <String, SembastTypeAdapter>{};

  /// Codec with the needed adapters
  JsonEncodableCodec({Iterable<SembastTypeAdapter> adapters}) {
    if (adapters != null) {
      for (var adapter in adapters) {
        assert(_adapters[adapter.name] == null,
            'Adapter already exists for ${adapter.name}');
        _adapters[adapter.name] = adapter;
      }
    }
    _decoder = _Decoder(this);
    _encoder = _Encoder(this);
  }

  _Decoder _decoder;

  @override
  _Decoder get decoder => _decoder;

  _Encoder _encoder;

  @override
  _Encoder get encoder => _encoder;

  /// True if the value is one of the supported adapter types.
  bool supportsType(dynamic value) {
    if (_adapters != null) {
      for (var adapter in _adapters.values) {
        if (adapter.isType(value)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Default jsonEncodableCodec
final sembastDefaultJsonEncodableCodec =
    JsonEncodableCodec(adapters: sembastDefaultTypeAdapters);
