library tekartik_iodb.database_perf_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:tekartik_iodb/database.dart';
import 'package:tekartik_io_tools/platform_utils.dart';
import 'package:path/path.dart';
import 'dart:async';

void main() {
  useVMConfiguration();
  defineTests();
}

void defineTests() {
  group('perf', () {

    String dbPath = join(scriptDirPath, "tmp", "test.db");
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

    int putCount = 100;
    test('put/read $putCount', () {
      List<Future> futures = [];
      for (int i = 0; i < putCount; i++) {
        futures.add(db.put("value $i", i));

      }
      return Future.wait(futures).then((_) {
        return db.count().then((int count) {
          expect(count, putCount);
        });
      });
    });


  });
}
