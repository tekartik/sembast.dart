import 'package:sembast/sembast.dart' as compat;

import '../test_common.dart';

export 'package:sembast/sembast.dart';

export '../test_common.dart'
    hide
        Database,
        setupForTest,
        reOpen,
        Transaction,
        memoryDatabaseContext,
        DatabaseFactory,
        DatabaseTestContext;
export 'src/test_defs.dart';

Future<compat.Database> setupForTest(DatabaseTestContext ctx, String name) =>
    ctx.open(dbPathFromName(name));

class DatabaseTestContext {
  compat.DatabaseFactory factory;

  // String dbPath;

  // Delete the existing and open the database
  // ignore: always_require_non_null_named_parameters
  Future<compat.Database> open(String dbPath, {int version}) async {
    assert(dbPath != null, 'dbPath cannot be null');
    // this.dbPath = dbPath;

    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}
