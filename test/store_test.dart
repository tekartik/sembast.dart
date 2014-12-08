library tekartik_iodb.store_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_iodb/database_memory.dart';
import 'database_test.dart';

void main() {
  useVMConfiguration();
  defineTests(memoryDatabaseFactory);
}

void defineTests(DatabaseFactory factory) {

  group('store', () {
 
    Database db;

        setUp(() {
          return setupForTest(factory).then((Database database) {
            db = database;
          });
        });


    tearDown(() {
      db.close();
    });

    test('put/get', () {
      Store store1 = db.getStore("test1");
      Store store2 = db.getStore("test2");
      return store1.put("hi", 1).then((int key) {
        expect(key, 1);
      }).then((_) {
        return store2.put("ho", 1).then((int key) {
          expect(key, 1);
        });
      }).then((_) {
        return store1.get(1).then((String value) {
          expect(value, "hi");
        });
      }).then((_) {
        return store2.get(1).then((String value) {
          expect(value, "ho");
        });
      }).then((_) {
        return db.reOpen().then((_) {
          return store1.get(1).then((String value) {
            expect(value, "hi");
          });
        }).then((_) {
          return store2.get(1).then((String value) {
            expect(value, "ho");
          });

        });
      });
    });
  });
}
