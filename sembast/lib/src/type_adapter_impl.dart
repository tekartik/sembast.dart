import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/sembast_codec_impl.dart';
import 'package:sembast/src/utils.dart';
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/value_utils.dart';

String _decodeType(String typeKey) {
  if (typeKey.startsWith('@')) {
    return typeKey.substring(1);
  }
  return null;
}

class _JsonEncodeState {
  bool changed;
  dynamic encodable;
}

class _JsonEncoder extends Converter<Map<String, dynamic>, String> {
  final _SembastDataJsonCodec codec;

  _JsonEncoder(this.codec);

  dynamic _toEncodable(dynamic decoded) =>
      _toEncodableOrNull(decoded) ?? decoded;

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
  String convert(Map<String, dynamic> input) => json.encode(input,
      toEncodable: codec._adapters.isEmpty ? null : _toEncodable);

  void _toMapSerializable(_JsonEncodeState state, Map map) {
    Map clone;
    map.forEach((key, value) {
      _toSerializable(state, value);
      if (state.changed) {
        clone ??= cloneMap(map);
        clone[key] = state.encodable;
      }
    });
    state.changed = clone != null;
    state.encodable = clone ?? map;
  }

  void _toListSerializable(_JsonEncodeState state, List list) {
    List clone;
    for (var i = 0; i < list.length; i++) {
      var value = list[i];
      _toSerializable(state, value);
      if (state.changed) {
        clone ??= cloneList(list);
        clone[i] = state.encodable;
      }
    }
    state.changed = clone != null;
    state.encodable = clone ?? list;
  }

  void _toSerializable(_JsonEncodeState state, dynamic value) {
    if (isBasicTypeFieldValueOrNull(value)) {
      state.changed = false;
      state.encodable = value;
    } else if (value is Map) {
      _toMapSerializable(state, value);
      return;
    } else if (value is List) {
      _toListSerializable(state, value);
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

  @override
  dynamic toSerializable(dynamic value) {
    var state = _JsonEncodeState();
    _toSerializable(state, value);
    return state.encodable;
  }
}

class _JsonDecodeState {
  bool changed;
  dynamic decoded;
}

class _JsonDecoder extends Converter<String, Map<String, dynamic>> {
  final _SembastDataJsonCodec codec;

  _JsonDecoder(this.codec);

  dynamic _reviver(Object key, Object value) =>
      _reviverOrNull(key, value) ?? value;
  dynamic _reviverOrNull(Object key, Object value) {
    // Handle special @ key to key the object as is
    if (key != '@') {
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
    }
    return null;
  }

  @override
  Map<String, dynamic> convert(String input) {
    var result =
        json.decode(input, reviver: codec._adapters.isEmpty ? null : _reviver);
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }

  dynamic fromSerializable(dynamic value) {
    var state = _JsonDecodeState();
    _fromSerializable(state, value);
    return state.decoded;
  }

  void _fromMapSerializable(_JsonDecodeState state, Map map) {
    var reviver = _reviverOrNull(null, map);
    if (reviver != null) {
      state.changed = true;
      state.decoded = reviver;
    } else {
      Map clone;
      map.forEach((key, value) {
        _fromSerializable(state, value);
        if (state.changed) {
          clone ??= cloneMap(map);
          clone[key] = state.decoded;
        }
      });
      state.changed = clone != null;
      state.decoded = clone ?? map;
    }
  }

  void _fromListSerializable(_JsonDecodeState state, List list) {
    List clone;
    for (var i = 0; i < list.length; i++) {
      var value = list[i];
      _fromSerializable(state, value);
      if (state.changed) {
        clone ??= cloneList(list);
        clone[i] = state.decoded;
      }
    }
    state.changed = clone != null;
    state.decoded = clone ?? list;
  }

  void _fromSerializable(_JsonDecodeState state, dynamic value) {
    if (isBasicTypeFieldValueOrNull(value)) {
      state.changed = false;
      state.decoded = value;
    } else if (value is Map) {
      _fromMapSerializable(state, value);
      return;
    } else if (value is List) {
      _fromListSerializable(state, value);
      return;
    }
  }
}

class _Converter<S, T> extends Converter<S, T> {
  final T Function(S input) _convert;

  _Converter(this._convert);

  @override
  T convert(S input) => _convert(input);
}

/// Convert date time to a iso8601 string.
///
/// Be aware that the format can differ on the platform, web will use milliseconds
/// precision while io will have microseconds precision.
class _DateTimeAdapter extends SembastTypeAdapter<DateTime, String>
    with TypeAdapterCodecMixin<DateTime, String> {
  _DateTimeAdapter() {
    // Encode to string
    encoder =
        _Converter<DateTime, String>((dateTime) => dateTime.toIso8601String());
    // Decode from string
    decoder = _Converter<String, DateTime>((text) => DateTime.parse(text));
  }

  @override
  String get name => 'DateTime';
}

/// Convert a timestamp to a iso8601 string.
///
/// Be aware that the format can differ on the platform, web will use milliseconds
/// precision while io will have microseconds precision.
class _TimestampAdapter extends SembastTypeAdapter<Timestamp, String>
    with TypeAdapterCodecMixin<Timestamp, String> {
  _TimestampAdapter() {
    // Encode to string
    encoder = _Converter<Timestamp, String>(
        (timestamp) => timestamp.toIso8601String());
    // Decode from string
    decoder = _Converter<String, Timestamp>((text) => Timestamp.parse(text));
  }

  @override
  String get name => 'Timestamp';
}

/// Convert UInt8List time to base64 text.
class _BlobAdapter extends SembastTypeAdapter<Blob, String>
    with TypeAdapterCodecMixin<Blob, String> {
  _BlobAdapter() {
    // Encode to string
    encoder = _Converter<Blob, String>((blob) => blob.toBase64());
    // Decode from string
    decoder = _Converter<String, Blob>((text) => Blob.fromBase64(text));
  }

  @override
  String get name => 'Blob';
}

/// Simple timestamp adapter to convert to iso8601 string.
final SembastTypeAdapter<Timestamp, String> sembastTimestampAdapter =
    _TimestampAdapter();

/// Simple datetime adapter to convert to iso8601 string.
final SembastTypeAdapter<DateTime, String> sembastDateTimeAdapter =
    _DateTimeAdapter();

/// Simple blob adapter to convert to base64 string.
final SembastTypeAdapter<Blob, String> sembastBlobAdapter = _BlobAdapter();

/// Base type adapter codec
abstract class SembastTypeAdapter<S, T> extends Codec<S, T> {
  /// name used in the annoation '@${name}'
  String get name;

  /// True if the value is the proper type.
  bool isType(dynamic value);
}

/// Mixin for type adapters
mixin TypeAdapterCodecMixin<S, T> implements SembastTypeAdapter<S, T> {
  // bool get isType(dynamic value);

  @override
  bool isType(dynamic value) => value is S;

  @override
  Converter<S, T> encoder;
  @override
  Converter<T, S> decoder;

  @override
  String toString() => 'TypeAdapter($name)';
}

/// Allow for an empty signature as it uses the default format.
DefaultSembastCodec sembastCodecWithAdapters(
    Iterable<SembastTypeAdapter> adapters,
    {String signature}) {
  var dataCodec = _SembastDataJsonCodec(adapters: adapters);
  var sembastCodec =
      DefaultSembastCodecImpl(signature: signature, codec: dataCodec);
  return sembastCodec;
}

/// Json Codec with supports for DateTime and Blobs (UInt8List)
DefaultSembastCodec defaultSembastCodec =
    sembastCodecWithAdapters([sembastBlobAdapter, sembastTimestampAdapter]);

/// Default sembast codec.
abstract class DefaultSembastCodec implements SembastCodec {
  /// True if type is supported.
  bool supportsType(dynamic value);

  /// Sanitize any object to a json encodable format.
  dynamic toSerializable(dynamic value);

  /// Desrialize from a json encodable format.
  dynamic fromSerializable(dynamic value);
}

/// The sembast codec to use to read/write records.
///
/// It uses a user defined [codec] that must convert between a map and a
/// single line string.
///
/// It must have a public [signature], typically a comprehensive ascii name.
class DefaultSembastCodecImpl extends SembastCodecImpl
    implements SembastCodec, DefaultSembastCodec {
  /// [codec] must convert between a map and a single line string
  DefaultSembastCodecImpl(
      {String signature, @required Codec<dynamic, String> codec})
      : super(signature: signature, codec: codec);

  _SembastDataJsonCodec get _codec => codec as _SembastDataJsonCodec;
  @override
  bool supportsType(value) {
    if (_codec._adapters != null) {
      for (var adapter in _codec._adapters.values) {
        if (adapter.isType(value)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  dynamic fromSerializable(dynamic value) =>
      _codec._decoder.fromSerializable(value);

  @override
  dynamic toSerializable(dynamic value) =>
      _codec._encoder.toSerializable(value);
}

class _SembastDataJsonCodec extends Codec<Map<String, dynamic>, String> {
  final _adapters = <String, SembastTypeAdapter>{};

  _SembastDataJsonCodec({Iterable<SembastTypeAdapter> adapters}) {
    if (adapters != null) {
      for (var adapter in adapters) {
        assert(_adapters[adapter.name] == null,
            'Adapter already exists for ${adapter.name}');
        _adapters[adapter.name] = adapter;
      }
    }
    _decoder = _JsonDecoder(this);
    _encoder = _JsonEncoder(this);
  }

  _JsonDecoder _decoder;

  @override
  _JsonDecoder get decoder => _decoder;

  _JsonEncoder _encoder;

  @override
  _JsonEncoder get encoder => _encoder;
}
