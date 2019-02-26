import 'dart:async';

/// Simple cooperate that checks every 4ms
class Cooperator {
  // Cooperate mode
  //
  final bool cooperateOn = true;
  var cooperateStopWatch = Stopwatch()..start();

  // Need to cooperate every 16 milliseconds
  bool get needCooperate =>
      cooperateOn && cooperateStopWatch.elapsedMilliseconds > 4;

  FutureOr cooperate() {
    if (needCooperate) {
      cooperateStopWatch
        ..stop()
        ..reset()
        ..start();
      return Future.delayed(Duration(milliseconds: 0));
    } else {
      return null;
    }
    // await Future.value();
    //print('breath');
  }
}
