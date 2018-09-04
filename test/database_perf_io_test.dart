import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';
import 'package:sembast/sembast_io.dart';

void main() {
  test('perf', () async {
    Future perf(int recordCount, int times,
        {int recordSize,
        bool bigRecord,
        int transactionCount,
        bool inTransaction}) async {
      inTransaction ??= transactionCount != null && transactionCount > 0;
      transactionCount ??= inTransaction ? 1 : 0;
      String _record = bigRecord == true
          ? List.generate<String>(3000, (i) => '$i').join('')
          : "'some value";
      recordSize = _record.length;

      var dbPath = join('.dart_tool', 'sembast', 'test',
          'perf_${recordCount}_${times}_${recordSize}_${transactionCount}.db');
      try {
        await new File(dbPath).delete();
      } catch (_) {}
      await new Directory(dirname(dbPath)).create(recursive: true);
      var db = await databaseFactoryIo.openDatabase(dbPath);

      try {
        var sw = Stopwatch();
        sw.start();

        Future _do(StoreExecutor executor, int recordCount, int times) async {
          for (int j = 0; j < times; j++) {
            for (int i = 0; i < recordCount; i++) {
              await executor.put(_record, i);
            }
          }
        }

        if (inTransaction == true) {
          for (int k = 0; k < transactionCount; k++) {
            await db.transaction((Transaction txn) async {
              await _do(txn, recordCount, times);
            });
          }
        } else {
          await _do(db, recordCount, times);
        }
        sw.stop();
        List<String> rows = [
          '$recordCount', '$times',
          inTransaction == true ? '$transactionCount' : ' ',
          // bigRecord == true ? 'BIG': ' ',
          '${_record.length}',
          '${sw.elapsedMilliseconds}'
        ];
        //print('$recordCount record(s) $times times: ${sw.elapsed}${inTransaction == true ? ' in transaction' : ''}');

        print('|${rows.join('|')}|');
      } finally {
        await db.close();
      }
    }

    print('|nb records|times|transaction|size kb|elapsed ms|');
    print(List.generate<String>(6, (_) => '|').join('---'));

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
  });
}
