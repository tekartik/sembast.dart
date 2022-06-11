@TestOn('vm')
library sembast.database_perf_io_test;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

import 'test_common.dart';

void main() {
  test('perf', () async {
    Future perf(int recordCount, int times,
        {int? recordSize,
        bool? bigRecord,
        int? transactionCount,
        bool? inTransaction}) async {
      inTransaction ??= transactionCount != null && transactionCount > 0;
      transactionCount ??= inTransaction ? 1 : 0;
      final recordContent = bigRecord == true
          ? List.generate(3000, (i) => '$i').join('')
          : 'some value';
      recordSize = recordContent.length;

      var dbPath = join('.dart_tool', 'sembast', 'test',
          'perf_${recordCount}_${times}_${recordSize}_$transactionCount.db');
      try {
        await File(dbPath).delete();
      } catch (_) {}
      await Directory(dirname(dbPath)).create(recursive: true);
      var db = await databaseFactoryIo.openDatabase(dbPath);
      // Remove cooperator to get raw result
      setDatabaseCooperator(db, null);

      var store = StoreRef<int, String>.main();
      try {
        var sw = Stopwatch();
        sw.start();

        Future doPut(DatabaseClient client, int recordCount, int times) async {
          for (var j = 0; j < times; j++) {
            for (var i = 0; i < recordCount; i++) {
              await store.record(i).put(client, recordContent);
            }
          }
        }

        if (inTransaction == true) {
          for (var k = 0; k < transactionCount; k++) {
            await db.transaction((Transaction txn) async {
              await doPut(txn, recordCount, times);
            });
          }
        } else {
          await doPut(db, recordCount, times);
        }
        sw.stop();
        final rows = <String>[
          '$recordCount', '$times',
          inTransaction == true ? '$transactionCount' : ' ',
          // bigRecord == true ? 'BIG': ' ',
          '${recordContent.length}',
          '${sw.elapsedMilliseconds}'
        ];
        //print('$recordCount record(s) $times times: ${sw.elapsed}${inTransaction == true ? ' in transaction' : ''}');

        print('|${rows.join('|')}|');
      } finally {
        await db.close();
      }
    }

    print('|nb records|times|transaction|size kb|elapsed ms|');
    print(List.generate(6, (_) => '|').join('---'));

    await perf(1, 1);
    await perf(10, 1);
    await perf(100, 1);
    await perf(100, 20);
    await perf(1000, 1);
    await perf(1000, 5);
    await perf(1, 1, bigRecord: true);
    await perf(10, 1, bigRecord: true);
    await perf(100, 1, bigRecord: true);
    await perf(100, 20, bigRecord: true);
    await perf(1000, 1, bigRecord: true);
    await perf(1000, 5, bigRecord: true);
    await perf(100, 1, inTransaction: true);
    await perf(100, 1, transactionCount: 5);
    await perf(100, 1, transactionCount: 10);
    await perf(100, 20, inTransaction: true);
    await perf(1000, 1, inTransaction: true);
    await perf(1000, 5, inTransaction: true);
    await perf(1000, 20, inTransaction: true);
    await perf(10000, 1, inTransaction: true);
    await perf(10000, 5, inTransaction: true);
    await perf(100, 1, inTransaction: true, bigRecord: true);
    await perf(100, 20, inTransaction: true, bigRecord: true);
    await perf(1000, 1, inTransaction: true, bigRecord: true);
    await perf(1000, 5, inTransaction: true, bigRecord: true);
    await perf(1000, 5, transactionCount: 5, bigRecord: true);
    await perf(1000, 5, transactionCount: 10, bigRecord: true);
    await perf(1000, 20, inTransaction: true, bigRecord: true);
    await perf(10000, 1, inTransaction: true, bigRecord: true);
    await perf(10000, 5, inTransaction: true, bigRecord: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
