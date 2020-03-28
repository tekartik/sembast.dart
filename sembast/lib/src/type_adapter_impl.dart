import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/sembast.dart';

String _decodeType(String typeKey) {
  if (typeKey.startsWith('@')) {
    return typeKey.substring(1);
  }
  return null;
}

class _JsonEncoder extends Converter<Map<String, dynamic>, String> {
  final _SembastDataJsonCodec codec;

  _JsonEncoder(this.codec);

  dynamic _toEncodable(dynamic decoded) {
    for (var entry in codec._adapters.entries) {
      var adapter = entry.value;
      if (adapter.isType(decoded)) {
        return <String, dynamic>{'@${adapter.name}': adapter.encode(decoded)};
      }
    }
    return decoded;
  }

  @override
  String convert(Map<String, dynamic> input) => json.encode(input,
      toEncodable: codec._adapters.isEmpty ? null : _toEncodable);
}

class _JsonDecoder extends Converter<String, Map<String, dynamic>> {
  final _SembastDataJsonCodec codec;

  _JsonDecoder(this.codec);

  dynamic _reviver(Object key, Object value) {
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
    return value;
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
}

class _Converter<S, T> extends Converter<S, T> {
  final T Function(S input) _convert;

  _Converter(this._convert);

  @override
  T convert(S input) => _convert(input);
}

/// Convert date time to iso8601 string.
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

/// Convert UInt8List time to base64 text.
class _BlobAdapter extends SembastTypeAdapter<Blob, String>
    with TypeAdapterCodecMixin<Blob, String> {
  _BlobAdapter() {
    // Encode to string
    encoder = _Converter<Blob, String>((blob) => base64Encode(blob.bytes));
    // Decode from string
    decoder = _Converter<String, Blob>((text) => Blob(base64Decode(text)));
  }

  @override
  String get name => 'Blob';
}

/// Sembast blob definition
class Blob {
  /// Blob bytes. null not supported.
  final Uint8List bytes;

  /// Blob creation
  Blob(this.bytes);

  /// Blob creation from int list.
  Blob.fromList(List<int> list) : bytes = Uint8List.fromList(list);

  bool _listsAreEqual(List one, List two) {
    var i = -1;
    return one.every((element) {
      i++;

      return two[i] == element;
    });
  }

  @override
  int get hashCode => bytes.length;

  @override
  bool operator ==(other) =>
      other is Blob && _listsAreEqual(bytes, other.bytes);

  @override
  String toString() => 'Blob(len: ${bytes?.length})';
}

/// Simple datetime adapter to convert to iso8601 string.
final SembastTypeAdapter<DateTime, String> sembastDateTimeAdapter =
    _DateTimeAdapter();

/// Simple blob adapter to convert to base64 string.
final SembastTypeAdapter<Blob, String> sembastBlobAdapter = _BlobAdapter();

/// Allow for an empty signature as it uses the default format.
SembastCodec sembastCodecWithAdapters(Iterable<SembastTypeAdapter> adapters,
    {String signature}) {
  var dataCodec = _SembastDataJsonCodec(adapters: adapters);
  var sembastCodec = SembastCodec(signature: signature, codec: dataCodec);
  return sembastCodec;
}

/// Json Codec with supports for DateTime and Blobs (UInt8List)
SembastCodec sembastExtendedCodec =
    sembastCodecWithAdapters([sembastDateTimeAdapter, sembastBlobAdapter]);

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
