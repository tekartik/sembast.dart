import 'dart:convert';

import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

class _Converter<S, T> extends Converter<S, T> {
  _Converter(this._convert);
  final T Function(S input) _convert;

  @override
  T convert(S input) => _convert(input);
}

/// Convert date time to a iso8601 string.
///
/// Be aware that the format can differ on the platform, web will use milliseconds
/// precision while io will have microseconds precision.
class _DateTimeAdapter extends SembastTypeAdapter<DateTime, String>
    with _TypeAdapterCodecMixin<DateTime, String> {
  _DateTimeAdapter([this._name = 'DateTime']) {
    // Encode to string
    encoder = _Converter<DateTime, String>(
      (dateTime) => dateTime.toIso8601String(),
    );
    // Decode from string
    decoder = _Converter<String, DateTime>((text) => DateTime.parse(text));
  }

  final String _name;

  @override
  String get name => _name;
}

/// Convert a timestamp to a iso8601 string.
///
/// Be aware that the format can differ on the platform, web will use milliseconds
/// precision while io will have microseconds precision.
class _TimestampAdapter extends SembastTypeAdapter<Timestamp, String>
    with _TypeAdapterCodecMixin<Timestamp, String> {
  _TimestampAdapter([this._name = 'Timestamp']) {
    // Encode to string
    encoder = _Converter<Timestamp, String>(
      (timestamp) => timestamp.toIso8601String(),
    );
    // Decode from string
    decoder = _Converter<String, Timestamp>((text) => Timestamp.parse(text));
  }

  final String _name;

  @override
  String get name => _name;
}

/// Convert UInt8List time to base64 text.
class _BlobAdapter extends SembastTypeAdapter<Blob, String>
    with _TypeAdapterCodecMixin<Blob, String> {
  _BlobAdapter([this._name = 'Blob']) {
    // Encode to string
    encoder = _Converter<Blob, String>((blob) => blob.toBase64());
    // Decode from string
    decoder = _Converter<String, Blob>((text) => Blob.fromBase64(text));
  }

  final String _name;

  @override
  String get name => _name;
}

/// Simple timestamp adapter to convert to iso8601 string.
final SembastTypeAdapter<Timestamp, String> sembastTimestampAdapter =
    _TimestampAdapter();

/// Simple datetime adapter to convert to iso8601 string.
final SembastTypeAdapter<DateTime, String> sembastDateTimeAdapter =
    _DateTimeAdapter();

/// Simple blob adapter to convert to base64 string.
final SembastTypeAdapter<Blob, String> sembastBlobAdapter = _BlobAdapter();

/// V2 timestamp adapter, using the camelCase `timestamp` name (meant to be
/// used with the `$` prefix).
final SembastTypeAdapter<Timestamp, String> sembastTimestampAdapterV2 =
    _TimestampAdapter('timestamp');

/// V2 datetime adapter, using the camelCase `dateTime` name (meant to be
/// used with the `$` prefix).
final SembastTypeAdapter<DateTime, String> sembastDateTimeAdapterV2 =
    _DateTimeAdapter('dateTime');

/// V2 blob adapter, using the camelCase `blob` name (meant to be used with
/// the `$` prefix).
final SembastTypeAdapter<Blob, String> sembastBlobAdapterV2 = _BlobAdapter(
  'blob',
);

/// Base type adapter codec
abstract class SembastTypeAdapter<S, T> extends Codec<S, T> {
  /// name used in the annoation '@${name}'
  String get name;

  /// True if the value is the proper type.
  bool isType(dynamic value);
}

/// Mixin for type adapters
mixin _TypeAdapterCodecMixin<S, T> implements SembastTypeAdapter<S, T> {
  // bool get isType(dynamic value);

  @override
  bool isType(dynamic value) => value is S;

  @override
  late Converter<S, T> encoder;
  @override
  late Converter<T, S> decoder;

  @override
  String toString() => 'TypeAdapter($name)';
}

/// Support Timestamp and Blob
final sembastDefaultTypeAdapters = [
  sembastTimestampAdapter,
  sembastBlobAdapter,
];

/// V2 support for Timestamp and Blob, using camelCase names (meant to be
/// used with the `$` prefix).
final sembastDefaultTypeAdaptersV2 = [
  sembastTimestampAdapterV2,
  sembastBlobAdapterV2,
];
