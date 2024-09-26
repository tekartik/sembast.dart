library;

import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemory;

import 'all_test.dart';
import 'test_common.dart';

void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), 'FileSystemMemory');
    expect(memoryDatabaseContext.factory,
        const TypeMatcher<DatabaseFactoryMemory>());
  });

  defineMemoryDatabaseTests(memoryDatabaseContext);
  defineTests(memoryDatabaseContext);
}

void defineMemoryDatabaseTests(DatabaseTestContext ctx) {
  test('empty name', () async {
    final factory = memoryDatabaseContext.factory;
    var dbName = '';

    final db = await factory.openDatabase(dbName);
    var store = StoreRef<int, String>.main();
    var key = await store.add(db, 'hi');
    expect(await store.record(key).get(db), 'hi');

    // open same db again should match
    var db2 = await factory.openDatabase(dbName);
    expect(await store.record(key).get(db2), 'hi');

    await db.close();
    await db2.close();
  });
}
