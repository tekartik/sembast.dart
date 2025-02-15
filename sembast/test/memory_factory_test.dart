library;

// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('factory_memory', () {
    var factory = databaseFactoryMemory;
    test('hasStorage', () async {
      expect(factory.hasStorage, false);
    });

    test('newFactory', () async {
      var store = StoreRef<int, int>.main();
      var factory1 = newDatabaseFactoryMemory();
      var factory2 = newDatabaseFactoryMemory();
      // Using same database name
      var db1 = await factory1.openDatabase('path');
      var db2 = await factory2.openDatabase('path');
      var record = store.record(1);
      await record.put(db1, 123);
      await record.put(db2, 456);
      await db1.close();
      await db2.close();
      db1 = await factory1.openDatabase('path');
      db2 = await factory2.openDatabase('path');
      expect(await record.get(db1), 123);
      expect(await record.get(db2), 456);
      await db1.close();
      await db2.close();
    });

    test('openNewInMemoryDatabase', () async {
      var store = StoreRef<int, int>.main();
      var db = await openNewInMemoryDatabase();
      var db2 = await openNewInMemoryDatabase();
      await store.record(1).put(db, 123);
      await store.record(1).put(db2, 456);
      expect(await store.record(1).get(db), 123);
      expect(await store.record(1).get(db2), 456);
      await db.close();
      await db2.close();
    });
  });
}
