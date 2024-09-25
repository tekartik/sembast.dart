library sembast.utils.sembast_import_export_io;

import 'dart:io';

import 'package:sembast/src/common_import.dart';
import 'package:sembast/utils/sembast_import_export.dart';
export 'package:sembast/sembast.dart';

///
/// Write the export in a file (currently in .jsonl format)
///
Future<void> exportDatabaseToJsonlFile(Database db, String path,
    {List<String>? storeNames}) async {
  var file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(exportLinesToJsonlString(
      await exportDatabaseLines(db, storeNames: storeNames)));
}

///
/// Import database from a file (currently in .jsonl format)
///
Future<Database> importDatabaseFromFile(
    String path, DatabaseFactory dstFactory, String dstPath,
    {SembastCodec? codec, List<String>? storeNames}) async {
  var data = decodeImportAny(await File(path).readAsString());
  return await importDatabaseAny(data, dstFactory, dstPath,
      codec: codec, storeNames: storeNames);
}
