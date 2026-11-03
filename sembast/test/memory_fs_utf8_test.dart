library;

import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('memory_fs_utf8', () {
    // The memory file system read the lines through their code units,
    // a record with non ascii text was lost when reopening.
    test('non ascii text survives a reopen', () async {
      var factory = databaseFactoryMemoryFs;
      var store = StoreRef<int, Object>.main();
      var dbName = 'memory_fs_utf8.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(dbName);
      await store.record(1).put(db, {'text': 'été ✓ 日本 😀'});
      await store.record(2).put(db, 'ascii');
      await db.close();
      db = await factory.openDatabase(dbName);
      try {
        expect(await store.record(1).get(db), {'text': 'été ✓ 日本 😀'});
        expect(await store.record(2).get(db), 'ascii');
      } finally {
        await db.close();
      }
    });
  });
}
