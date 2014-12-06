library tekartik_iodb.record_test;

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

  group('record', () {
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

    test('properties', () {
      Store store = db.mainStore;
      Record record = new Record(store, "hi", 1);
      expect(record.store, store);
      expect(record.key, 1);
      expect(record.value, "hi");
      expect(record[Field.VALUE], "hi");
      expect(record[Field.KEY], 1);

      record = new Record(store, {
        "text": "hi",
        "int": 1,
        "bool": true
      }, "mykey");

      expect(record.store, store);
      expect(record.key, "mykey");
      expect(record.value, {
        "text": "hi",
        "int": 1,
        "bool": true
      });
      expect(record[Field.VALUE], record.value);
      expect(record[Field.KEY], record.key);
      expect(record["text"], "hi");
      expect(record["int"], 1);
      expect(record["bool"], true);
    });

    test('put/get', () {
      Store store = db.mainStore;
      Record record = new Record(store, "hi", 1);
      return store.putRecord(record).then((Record record) {
        expect(record.key, 1);
        expect(record.value, "hi");
        expect(record.deleted, false);
        expect(record.store, store);
      }).then((_) {
        return store.getRecord(1).then((Record record) {
          expect(record.key, 1);
          expect(record.value, "hi");
          expect(record.deleted, false);
          expect(record.store, store);
        });
      });
    });

  });
}
