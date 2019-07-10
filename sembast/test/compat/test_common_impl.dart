// basically same as the io runner but with extra output
import 'package:sembast/src/database_impl.dart';

// export 'package:dev_test/test.dart';
// ignore: deprecated_member_use_from_same_package
export 'package:sembast/src/dev_utils.dart' show devPrint;

DatabaseExportStat getDatabaseExportStat(SembastDatabase db) {
  return DatabaseExportStat.fromJson(db.toJson()["exportStat"] as Map);
}
