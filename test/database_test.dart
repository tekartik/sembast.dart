library test_utils_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/file_utils.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';



main() {
  useVMConfiguration();
  group('database', () {

    String dbPath = join(scriptDirPath, "tmp", "test.db");
    group('open', () {
      Database db;

      setUp(() {
        db = new Database();
        return Database.delete(dbPath);
      });

      tearDown(() {
        db.close();
      });

      test('open_no_version', () {
        return db.open(dbPath).then((_) {
          fail("should fail");
        }).catchError((_) {
          // opk
        });
      });

      test('open', () {
        return db.open(dbPath, 1).then((_) {
          expect(db.path, dbPath);
          expect(db.version, 1);
        });
      });

      test('open_then_open_no_version', () {
        return db.open(dbPath, 1).then((_) {
          db.close();
          return db.open(dbPath).then((_) {
            expect(db.path, dbPath);
            expect(db.version, 1);
          });
        });
      });

    });

    group('crud', () {
      Database db;

      setUp(() {
        db = new Database();
        return Database.delete(dbPath).then((_) {
          return db.open(dbPath, 1);
        });
      });

      tearDown(() {
        db.close();
      });

      test('insert', () {
        //return db.open();
      });


    });

  });
}
