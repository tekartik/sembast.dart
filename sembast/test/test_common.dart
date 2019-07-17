import 'package:sembast/src/api/v2/sembast.dart';
export 'package:sembast/src/api/v2/sembast.dart';
export 'src/test/test.dart';
export 'src/test_defs.dart';

class DatabaseTestContext {
  DatabaseFactory factory;

  // String dbPath;

  // Delete the existing and open the database
  // ignore: always_require_non_null_named_parameters
  Future<Database> open(String dbPath, {int version}) async {
    assert(dbPath != null, 'dbPath cannot be null');
    // this.dbPath = dbPath;

    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}

void unused(dynamic value) {}
