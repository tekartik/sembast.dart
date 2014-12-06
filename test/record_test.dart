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

    test('find_equals', () {
      Store store = db.mainStore;
      Record record1 = new Record(store, "hi", 1);
      Record record2 = new Record(store, "ho", 2);
      return store.putRecords([record1, record2]).then((_) {

        Finder finder = new Finder();
        finder.filter = new FilterPredicate(Field.VALUE, FilterOperation.EQUALS, "hi");
        store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record1);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new FilterPredicate(Field.VALUE, FilterOperation.EQUALS, "ho");
        store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 1);
          expect(records[0], record2);
        });
      }).then((_) {
        Finder finder = new Finder();
        finder.filter = new FilterPredicate(Field.VALUE, FilterOperation.EQUALS, "hum");
        store.findRecords(finder).then((List<Record> records) {
          expect(records.length, 0);
        });
      });
    });
  });
}
