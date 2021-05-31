import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/database_utils.dart';
import 'package:test/test.dart';

void main() {
  var store1 = StoreRef<int, int>('store1');
  var record1 = store1.record(1);
  group('src_database_utils_test', () {
    Database? db1;
    Future<Database> initDb1() async {
      await db1?.close();
      db1 = await newDatabaseFactoryMemory().openDatabase('db1');
      await record1.put(db1!, 1);
      return db1!;
    }

    test('databaseMerge', () async {
      var sourceDatabase = await initDb1();

      var db = await newDatabaseFactoryMemory().openDatabase('db');
      await databaseMerge(db, sourceDatabase: sourceDatabase);
      expect(await record1.get(db), 1);
      await databaseMerge(db, sourceDatabase: sourceDatabase);
      expect(await record1.get(db), 1);
      await databaseMerge(db,
          sourceDatabase: sourceDatabase, storeNames: [store1.name]);
      expect(await record1.get(db), 1);

      await record1.delete(sourceDatabase);
      await databaseMerge(db, sourceDatabase: sourceDatabase, storeNames: []);
      expect(await record1.get(db), 1);
      await databaseMerge(db,
          sourceDatabase: sourceDatabase, storeNames: [store1.name]);

      expect(await record1.get(db), isNull);
    });
  });
}
