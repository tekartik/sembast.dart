library sembast.test.memory_factory_test_;

import 'test_common.dart';
import 'all_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast.dart';

void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "_MemoryFileSystem");
    expect(memoryDatabaseContext.factory,
        new isInstanceOf<MemoryDatabaseFactory>());
  });

  defineMemoryDatabaseTests(memoryDatabaseContext);
  defineTests(memoryDatabaseContext);
}

defineMemoryDatabaseTests(DatabaseTestContext ctx) {
  test('null name', () async {
    DatabaseFactory factory = memoryDatabaseContext.factory;
    String dbName = null;

    Database db = await factory.openDatabase(dbName);
    var key = await db.put('hi');
    expect(await db.get(key), 'hi');

    // open null db again should not match
    db = await factory.openDatabase(dbName);
    expect(await db.get(key), isNull);
  });
}
