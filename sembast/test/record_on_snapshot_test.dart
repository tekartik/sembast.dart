// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/common_import.dart';

import 'test_common.dart';

void main() {
  group('record.onSnapshot', () {
    late Database db;
    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase(
        'record_on_snapshot_test.db',
      );
    });
    tearDown(() async {
      try {
        await db.close();
      } catch (_) {}
    });

    // Test in all cases, created updated
    test('first', () async {
      // Key is an int, value is an int
      var store = StoreRef<int, int>.main();
      // Key is 1
      var record = store.record(1);

      Future<void> done() async {
        await record
            .onSnapshot(db)
            .firstWhere((element) => (element?.value ?? 0) > 2);
      }

      Future<void> doneWithTimeOut() async {
        await done().timeout(const Duration(milliseconds: 100));
      }

      try {
        await doneWithTimeOut();
        fail('should fail');
      } on TimeoutException catch (_) {
        // TimeoutException after 0:00:00.100000: Future not completed
        // print(_);
      }

      var doneFuture = done();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 2)).then((_) async {
          await record.put(db, 3);
        }),
      );
      await doneFuture;

      await record.put(db, 1);
      try {
        await doneWithTimeOut();
        fail('should fail');
      } on TimeoutException catch (_) {
        // print(_);
      }

      doneFuture = done();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 2)).then((_) async {
          await record.put(db, 3);
        }),
      );
      await doneFuture;

      await record.put(db, 1);
      doneFuture = done();
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 2)).then((_) async {
          await db.close();
        }),
      );
      try {
        // Bad state: No element
        await doneFuture;
      } catch (e) {
        // ignore: avoid_print
        print(e);
      }
    });

    test('records.onSnapshots', () async {
      // Key is an int, value is an int
      var store = StoreRef<int, int>.main();
      // Key is 1 and 2
      var record1 = store.record(1);
      var record2 = store.record(2);
      var records = store.records([1, 2]);
      expect(await records.onSnapshots(db).first, [null, null]);
      await record1.put(db, 1);
      await record2.put(db, 2);
      expect((await records.onSnapshots(db).first).map((e) => e?.value), [
        1,
        2,
      ]);
    });
  });
}
