import 'package:dev_test/dev_test.dart';
import 'package:path/path.dart';
import 'package:sembast/src/api/sembast.dart';

import '../compat/test_common.dart' as common;

export 'package:dev_test/dev_test.dart';

class DevDatabaseTestContext extends common.DatabaseTestContext {
  String get dbPath => joinAll(testDescriptions) + ".db";

  // Delete the existing and open the database
  @override
  Future<Database> open({String dbPath, int version}) async {
    dbPath ??= this.dbPath;
    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}
