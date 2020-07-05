import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sembast/sembast_io.dart';
import 'package:sembast/utils/sembast_import_export.dart';

/// Dump export of the database.
Future main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Missing single argument database path');
    exit(1);
  }
  var db = await databaseFactoryIo.openDatabase(arguments[0]);
  var map = await exportDatabase(db);
  print(const JsonEncoder.withIndent('  ').convert(map));
}
