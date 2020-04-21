import 'dart:async';

import 'package:meta/meta.dart';

/// Simple cooperate that checks every 4ms and wait for 100 microseconds.
///
/// While it degrades the performance (about 2%), it prevents heavy sort
/// algorithm from blocking the main isolate.
class Cooperator {
  /// True if activated.
  final bool cooperateOn = true;

  /// Timer.
  final _cooperateStopWatch = Stopwatch()..start();

  /// Need to cooperate every 16 milliseconds.
  bool get needCooperate =>
      cooperateOn && _cooperateStopWatch.elapsedMilliseconds > 4;

  /// Cooperate if needed.
  FutureOr cooperate() {
    if (needCooperate) {
      _cooperateStopWatch
        ..stop()
        ..reset()
        ..start();
      // Just don't make it 0, tested for best performance using Flutter
      // on a (non-recent) Nexus 5
      return Future.delayed(const Duration(microseconds: 100));
    } else {
      return null;
    }
    // await Future.value();
    //print('breath');
  }

  /// Stop the cooperator.
  void stop() {
    _cooperateStopWatch
      ..stop()
      ..reset();
  }

  /// Restart the cooperator
  void restart() {
    _cooperateStopWatch
      ..stop()
      ..reset()
      ..start();
  }
}

/// Check if cooperate is needed
bool cooperateNeeded(Cooperator cooperator) =>
    cooperator?.needCooperate ?? false;

/// Global cooperator.
final globalCooperator = Cooperator();

/// True if cooperator is disabled.
bool cooperatorDisabled = false;

/// Disable sembast cooperator.
///
/// Disable sembast cooperator that prevents heavy algorithms blocking the UI
/// thread. Should be called before any other call.
@visibleForTesting
void disableSembastCooperator() {
  globalCooperator?.stop();
  cooperatorDisabled = true;
}

/// Re-enable sembast cooperator.
@visibleForTesting
void enableSembastCooperator() {
  cooperatorDisabled = false;
  globalCooperator.restart();
}
