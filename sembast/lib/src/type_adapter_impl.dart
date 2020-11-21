import 'dart:convert';

import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

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
    with _TypeAdapterCodecMixin<DateTime, String> {
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
    with _TypeAdapterCodecMixin<Timestamp, String> {
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
    with _TypeAdapterCodecMixin<Blob, String> {
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
  sembastBlobAdapter
];
