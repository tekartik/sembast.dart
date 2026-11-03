import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/type_adapter_impl.dart';

/// Header key of an export giving its [SembastExportTypeEncoding] (its
/// prefix), absent from a legacy export.
const sembastExportTypePrefixKey = 'type_prefix';

/// How the custom types (`Timestamp`, `Blob` and the types of the codec
/// adapters) are encoded in an export: the prefix of the type keys. The type
/// names are the names of the codec adapters as is (`Timestamp`, `Blob` for
/// the default codec), whatever the prefix.
enum SembastExportTypeEncoding {
  /// `@` prefix: `{"@Timestamp": ...}`, `{"@Blob": ...}`, a map looking like
  /// one is escaped as `{"@": {...}}`. The legacy encoding.
  at('@'),

  /// `$` prefix: `{"$Timestamp": ...}`, `{"$Blob": ...}`, a map looking like
  /// one is escaped as `{"$": {...}}`.
  dollar(r'$');

  const SembastExportTypeEncoding(this.prefix);

  /// The prefix of the encoded type keys.
  final String prefix;
}

/// The encoding of an export prefix, null if unknown.
SembastExportTypeEncoding? sembastExportTypeEncodingFromPrefix(Object? prefix) {
  for (var encoding in SembastExportTypeEncoding.values) {
    if (encoding.prefix == prefix) {
      return encoding;
    }
  }
  return null;
}

/// The encoding given by an export header, null for a legacy export (no
/// [sembastExportTypePrefixKey]).
///
/// Throws a [FormatException] for an unknown prefix or when the encoding (a
/// legacy export being [SembastExportTypeEncoding.at]) is not in [allowed]
/// (all allowed when null).
SembastExportTypeEncoding? sembastExportHeaderTypeEncoding(
  Map header, {
  Iterable<SembastExportTypeEncoding>? allowed,
}) {
  SembastExportTypeEncoding? encoding;
  if (header.containsKey(sembastExportTypePrefixKey)) {
    var prefix = header[sembastExportTypePrefixKey];
    encoding = sembastExportTypeEncodingFromPrefix(prefix);
    if (encoding == null) {
      throw FormatException('Unsupported export type prefix $prefix');
    }
  }
  if (allowed != null) {
    var actual = encoding ?? SembastExportTypeEncoding.at;
    if (!allowed.contains(actual)) {
      throw FormatException(
        'Export type encoding ${actual.name} (${actual.prefix}) not allowed '
        '(allowed: ${allowed.map((e) => e.name).join(', ')})',
      );
    }
  }
  return encoding;
}

/// The codec encoding and decoding the values of an export in [encoding],
/// for the types of [adapters] (their names as is).
JsonEncodableCodec sembastExportTypeEncodingCodec(
  SembastExportTypeEncoding encoding,
  Iterable<SembastTypeAdapter> adapters,
) => JsonEncodableCodec(adapters: adapters, prefix: encoding.prefix);
