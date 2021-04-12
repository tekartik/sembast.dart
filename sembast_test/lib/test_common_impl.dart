// basically same as the io runner but with extra output
// ignore_for_file: implementation_imports
import 'package:sembast/src/database_impl.dart';

DatabaseExportStat getDatabaseExportStat(SembastDatabase db) {
  return DatabaseExportStat.fromJson(db.toJson()['exportStat'] as Map);
}
