import 'package:sembast/src/api/sembast.dart';

export 'package:test_api/test_api.dart' show TypeMatcher;

export 'src/test/test.dart';
export 'src/test_defs.dart';

class DatabaseTestContext {
  DatabaseFactory factory;

  String dbPath;

  // Delete the existing and open the database
  Future<Database> open({String dbPath, int version}) async {
    this.dbPath = dbPath ?? this.dbPath;
    assert(dbPath != null, 'dbPath cannot be null');
    await factory.deleteDatabase(dbPath);
    return await factory.openDatabase(dbPath, version: version);
  }
}

void unused(dynamic value) {}
