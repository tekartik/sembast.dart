library;

import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/api/protected/database.dart'
    show SembastDatabaseMixinAccessExt;
import 'package:sembast/src/api/protected/database.dart';
import 'package:test/test.dart';

void main() {
  group('database_factory_sandbox', () {
    test('open/exists/delete', () async {
      var factory = newDatabaseFactoryMemory();
      var sandboxed = factory.sandbox(path: 'sandbox');
      var store = StoreRef<String, String>.main();
      var record = store.record('key');

      var db = await sandboxed.openDatabase('test.db');
      await record.put(db, 'value');

      // The database is visible in the delegate factory under the sandbox
      // root.
      expect(
        await factory.databaseExists(p.join('sandbox', 'test.db')),
        isTrue,
      );
      expect(await factory.databaseExists('test.db'), isFalse);
      expect(await sandboxed.databaseExists('test.db'), isTrue);

      var sameDb = await factory.openDatabase(p.join('sandbox', 'test.db'));
      expect(sameDb, same(db));
      expect(await record.get(sameDb), 'value');
      expect(sameDb.isClosed, isFalse);
      await db.close();
      // Same should be closed too
      expect(sameDb.isClosed, isTrue);

      await sandboxed.deleteDatabase('test.db');
      expect(await sandboxed.databaseExists('test.db'), isFalse);
      expect(
        await factory.databaseExists(p.join('sandbox', 'test.db')),
        isFalse,
      );
    });

    test('absolute path', () async {
      var factory = newDatabaseFactoryMemory();
      var sandboxed = factory.sandbox(path: 'sandbox');
      var db = await sandboxed.openDatabase('${p.separator}test.db');
      await db.close();
      expect(
        await factory.databaseExists(p.join('sandbox', 'test.db')),
        isTrue,
      );
    });

    test('sandbox of sandbox', () async {
      var factory = newDatabaseFactoryMemory();
      var sandboxed = factory.sandbox(path: 'one').sandbox(path: 'two');
      var db = await sandboxed.openDatabase('test.db');
      await db.close();
      expect(
        await factory.databaseExists(p.join('one', 'two', 'test.db')),
        isTrue,
      );
    });

    test('escape attempt', () async {
      var factory = newDatabaseFactoryMemory();
      var sandboxed = factory.sandbox(path: 'sandbox');
      expect(
        () => sandboxed.openDatabase(p.join('..', 'test.db')),
        throwsArgumentError,
      );
      expect(() => sandboxed.openDatabase('.'), throwsArgumentError);
    });

    test('hasStorage', () {
      var factory = newDatabaseFactoryMemory();
      expect(factory.sandbox(path: 'sandbox').hasStorage, factory.hasStorage);
    });
  });
}
