library sembast.database_perf_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'dart:async';
import 'database_test.dart';

void main() {
  useVMConfiguration();
  defineTests(ioDatabaseFactory);
}

void defineTests(DatabaseFactory factory) {

  group('perf', () {

    Database db;

    setUp(() {
      return setupForTest(factory).then((Database database) {
        db = database;
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

    test('put/read in transaction $putCount', () {
      return db.inTransaction(() {
        List<Future> futures = [];
        for (int i = 0; i < putCount; i++) {
          futures.add(db.put("value $i", i));

        }
        return Future.wait(futures);
      }).then((_) {
        return db.count().then((int count) {
          expect(count, putCount);

        });
      });
    });

  });

}
