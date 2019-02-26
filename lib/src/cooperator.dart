class Cooperator {
//
  // Cooperate mode
  //
  bool cooperateMode = true;
  var cooperateStopWatch = Stopwatch()..start();

  // Need to cooperate every 16 milliseconds
  bool get needCooperate =>
      cooperateMode && cooperateStopWatch.elapsedMilliseconds > 4;

  Future cooperate() async {
    cooperateStopWatch
      ..stop()
      ..reset()
      ..start();
    await Future.delayed(Duration(milliseconds: 0));
    // await Future.value();
    //print('breath');
  }
}
