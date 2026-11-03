library;

import 'dart:io';

import 'package:sembast/src/common_import.dart';
import 'package:sembast/utils/sembast_import_export.dart';
export 'package:sembast/sembast.dart';

/// Write the export in a file (currently in .jsonl format)
///
/// See [exportDatabaseLines] for [client] and [options].
Future<void> exportDatabaseToJsonlFile(
  DatabaseClient client,
  String path, {
  List<String>? storeNames,
  SembastExportOptions? options,
}) async {
  var file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    exportLinesToJsonlString(
      await exportDatabaseLines(
        client,
        storeNames: storeNames,
        options: options,
      ),
    ),
  );
}

/// Import database from a file (currently in .jsonl format)
///
/// See [importDatabase] for [options].
Future<Database> importDatabaseFromFile(
  String path,
  DatabaseFactory dstFactory,
  String dstPath, {
  SembastCodec? codec,
  List<String>? storeNames,
  SembastImportOptions? options,
}) async {
  var data = decodeImportAny(await File(path).readAsString());
  return await importDatabaseAny(
    data,
    dstFactory,
    dstPath,
    codec: codec,
    storeNames: storeNames,
    options: options,
  );
}
