import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/cooperator.dart';

export 'package:sembast/src/api/v2/sembast.dart';
export 'package:sembast/src/dev_utils.dart';

export 'src/test/test.dart';
export 'src/test_defs.dart';

class DatabaseTestContext {
  late DatabaseFactory factory;

  // String dbPath;

  // Delete the existing and open the database
  // ignore: always_require_non_null_named_parameters
  Future<Database> open(String dbPath, {int? version}) async {
    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}

void unused(dynamic value) {}

void setDatabaseCooperator(Database db, Cooperator? cooperator) {
  (db as SembastDatabase).cooperator = cooperator;
}

SembastDatabase asSembastDatabase(Database db) => db as SembastDatabase;

SembastDatabaseFactoryMixin asSembastDatabaseFactoryMixin(
  DatabaseFactory factory,
) => factory as SembastDatabaseFactoryMixin;

Future<Database> reOpen(Database db, {DatabaseMode? mode}) {
  return (db as SembastDatabase).reOpen(
    DatabaseOpenOptions(
      mode: mode ?? db.openOptions.mode,
      codec: db.openOptions.codec,
      version: db.openOptions.version,
      onVersionChanged: db.openOptions.onVersionChanged,
    ),
  );
}

bool get isWeb => identical(1, 1.0);
