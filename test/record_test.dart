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

//    test('put', () {
//      return db.put("hi", 1).then((int key) {
//        expect(key, 1);
//      });
//    });
  });
}
