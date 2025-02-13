library;

import 'package:sembast/sembast_memory.dart';
// ignore_for_file: implementation_imports
import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemory;

import 'all_test.dart';
import 'test_common.dart';

void main() {
  test('type', () {
    expect(
      memoryFileSystemContext.fs.runtimeType.toString(),
      'FileSystemMemory',
    );
    expect(
      memoryDatabaseContext.factory,
      const TypeMatcher<DatabaseFactoryMemory>(),
    );
  });

  defineMemoryDatabaseTests(memoryDatabaseContext);
  defineTests(memoryDatabaseContext);
}

void defineMemoryDatabaseTests(DatabaseTestContext ctx) {
  test('in memory name', () async {
    final factory = memoryDatabaseContext.factory;
    var dbName = sembastInMemoryDatabasePath;

    final db = await factory.openDatabase(dbName);
    var store = StoreRef<int, String>.main();
    var key = await store.add(db, 'hi');
    print('key: $key');
    expect(await store.record(key).get(db), 'hi');

    // open null db again should not match
    var db2 = await factory.openDatabase(dbName);
    expect(await store.record(key).get(db2), isNull);

    await db.close();
    await db2.close();
  });
}
