// ignore_for_file: implementation_imports
import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/database_impl.dart';

export 'package:sembast/src/api/v2/sembast.dart';

export 'src/test/test.dart';
export 'src/test_defs.dart';

class DatabaseTestContext {
  late DatabaseFactory factory;

  // String dbPath;

  // Delete the existing and open the database
  // ignore: always_require_non_null_named_parameters
  Future<Database> deleteAndOpen(
    String dbPath, {
    int? version,
    SembastCodec? codec,
  }) async {
    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version, codec: codec);
  }

  Future<Database> open(
    String dbPath, {
    int? version,
    SembastCodec? codec,
  }) async {
    return await factory.openDatabase(dbPath, version: version, codec: codec);
  }
}

void unused(dynamic value) {}

void setDatabaseCooperator(Database db, Cooperator? cooperator) {
  (db as SembastDatabase).cooperator = cooperator;
}
