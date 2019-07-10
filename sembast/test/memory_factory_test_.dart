library sembast.test.memory_factory_test_;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemory;

import 'all_test.dart';
import 'dev_test_common.dart';

void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "FileSystemMemory");
    expect(devMemoryDatabaseContext.factory,
        const TypeMatcher<DatabaseFactoryMemory>());
  });

  defineMemoryDatabaseTests(devMemoryDatabaseContext);
  defineTests(devMemoryDatabaseContext);
}

void defineMemoryDatabaseTests(DevDatabaseTestContext ctx) {
  test('null name', () async {
    DatabaseFactory factory = devMemoryDatabaseContext.factory;
    String dbName;

    Database db = await factory.openDatabase(dbName);
    var key = await db.put('hi');
    expect(await db.get(key), 'hi');

    // open null db again should not match
    db = await factory.openDatabase(dbName);
    expect(await db.get(key), isNull);
  });
}
