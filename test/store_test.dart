library tekartik_iodb.store_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';


void main() {
  useVMConfiguration();
  defineTests();
}

void defineTests() {


  String dbPath = join(scriptDirPath, "tmp", "test.db");

  group('store', () {
    Database db;

    setUp(() {
      db = new Database();
      return Database.deleteDatabase(dbPath).then((_) {
        return db.open(dbPath, 1);
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
