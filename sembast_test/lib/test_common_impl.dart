// basically same as the io runner but with extra output
// ignore_for_file: implementation_imports
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';

DatabaseExportStat getDatabaseExportStat(Database db) {
  return DatabaseExportStat.fromJson(
    (db as SembastDatabase).toJson()['exportStat'] as Map,
  );
}
