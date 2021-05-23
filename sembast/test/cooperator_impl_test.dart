import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/env_utils.dart';

import 'test_common.dart';

/// Hardcore sleep!
void _sleep(int millis) {
  var sw = Stopwatch()..start();
  while (true) {
    if (sw.elapsedMilliseconds >= millis) {
      break;
    }
  }
}

void main() {
  group('cooperator', () {
    test('values', () {
      if (isRunningAsJavascript) {
        expect(cooperatorDelayMicroseconds, 24000);
        expect(cooperatorPauseMicroseconds, 1);
      } else {
        expect(cooperatorDelayMicroseconds, 4000);
        expect(cooperatorPauseMicroseconds, 100);
      }
    });

    Future<int> runCooperate({required int totalMs}) async {
      var cooperator = Cooperator();
      var stop = false;
      var sw = Stopwatch()..start();
      Future<int> run(int i) async {
        var sw = Stopwatch()..start();
        while (!stop) {
          _sleep(5);
          if (cooperator.needCooperate) {
            sw.stop();
            await cooperator.cooperate();
            sw.start();
          }
        }
        sw.stop();
        // print('task ${sw.elapsed}');
        return sw.elapsedMilliseconds;
      }

      var futures = <Future>[];
      for (var i = 0; i < 5; i++) {
        futures.add(run(i));
      }
      await Future.delayed(Duration(milliseconds: totalMs));
      stop = true;
      sw.stop();

      var tasksElapsedMs = 0;
      (await Future.wait(futures)).forEach((element) {
        tasksElapsedMs += element as int;
      });
      // print('global ${sw.elapsedMilliseconds} vs total tasks $tasksElapsedMs');
      return tasksElapsedMs;
    }

    test('cooperate', () async {
      var totalMs = 2000;
      var tasksElapsedMs = await runCooperate(totalMs: totalMs);
      expect(tasksElapsedMs, lessThan(totalMs * 1.2));
      expect(tasksElapsedMs, greaterThan(totalMs * 0.8));
    });
    test('cooperate100ms', () async {
      var totalMs = 2000;
      enableSembastCooperator(
          delayMicroseconds: 100000, pauseMicroseconds: 100000);
      var tasksElapsedMs = await runCooperate(totalMs: totalMs);
      enableSembastCooperator();
      expect(tasksElapsedMs, lessThan(totalMs * 0.8));
      expect(tasksElapsedMs, greaterThan(totalMs * 0.2));
    });
  });
}
