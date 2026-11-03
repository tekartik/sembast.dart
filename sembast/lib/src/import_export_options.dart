import 'package:sembast/src/export_type_encoding.dart';

/// Options of an export (`exportDatabase`, `exportDatabaseLines`,
/// `exportDatabaseToJsonlFile`).
class SembastExportOptions {
  /// Export options.
  const SembastExportOptions({this.storeNames, this.typeEncoding});

  /// The stores to export, all when null. It overrides the `storeNames`
  /// argument of the export functions.
  final List<String>? storeNames;

  /// The encoding of the custom types (`Timestamp`, `Blob`...), the legacy
  /// one (the database codec, `@Timestamp`) when null, see
  /// [SembastExportTypeEncoding].
  final SembastExportTypeEncoding? typeEncoding;

  /// A copy with the given fields changed.
  SembastExportOptions copyWith({
    List<String>? storeNames,
    SembastExportTypeEncoding? typeEncoding,
  }) => SembastExportOptions(
    storeNames: storeNames ?? this.storeNames,
    typeEncoding: typeEncoding ?? this.typeEncoding,
  );

  @override
  String toString() =>
      'SembastExportOptions(storeNames: $storeNames, '
      'typeEncoding: ${typeEncoding?.name})';
}

/// Options of an import (`importDatabase`, `importDatabaseLines`,
/// `importDatabaseAny`, `importDatabaseFromFile`).
class SembastImportOptions {
  /// Import options.
  const SembastImportOptions({this.storeNames, this.allowedTypeEncodings});

  /// The stores to import, all when null. It overrides the `storeNames`
  /// argument of the import functions.
  final List<String>? storeNames;

  /// The accepted export type encodings (an export without `type_prefix`
  /// being [SembastExportTypeEncoding.at]), all when null. Another one throws
  /// a `FormatException`.
  final List<SembastExportTypeEncoding>? allowedTypeEncodings;

  /// A copy with the given fields changed.
  SembastImportOptions copyWith({
    List<String>? storeNames,
    List<SembastExportTypeEncoding>? allowedTypeEncodings,
  }) => SembastImportOptions(
    storeNames: storeNames ?? this.storeNames,
    allowedTypeEncodings: allowedTypeEncodings ?? this.allowedTypeEncodings,
  );

  @override
  String toString() =>
      'SembastImportOptions(storeNames: $storeNames, '
      'allowedTypeEncodings: ${allowedTypeEncodings?.map((e) => e.name)})';
}
