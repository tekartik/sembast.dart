library sembast.test.memory_factory_test_;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemory;

import 'all_test.dart';
import 'test_common.dart';

void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "FileSystemMemory");
    expect(memoryDatabaseContext.factory,
        const TypeMatcher<DatabaseFactoryMemory>());
  });

  defineMemoryDatabaseTests(memoryDatabaseContext);
  defineTests(memoryDatabaseContext);
}

void defineMemoryDatabaseTests(DatabaseTestContext ctx) {
  test('null name', () async {
    DatabaseFactory factory = memoryDatabaseContext.factory;
    String dbName;

    Database db = await factory.openDatabase(dbName);
    var key = await db.put('hi');
    expect(await db.get(key), 'hi');

    // open null db again should not match
    var db2 = await factory.openDatabase(dbName);
    expect(await db2.get(key), isNull);
  });
}
