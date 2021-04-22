import 'dart:async';

import 'package:meta/meta.dart';
import 'package:sembast/src/env_utils.dart';

import 'common_import.dart';

/// Device optimized delay
const _cooperatorIoDelayMicrosecondsDefault = 4000;

/// Device optimized pause
const _cooperatorIoPauseMicrosecondsDefault = 100;

/// Web optimized delay
const _cooperatorWebDelayMicrosecondsDefault = 24000;

/// Web optimized pause
const _cooperatorWebPauseMicrosecondsDefault = 1;

/// Default delay
const _cooperatorDelayMicrosecondsDefault = isRunningAsJavascript
    ? _cooperatorWebDelayMicrosecondsDefault
    : _cooperatorIoDelayMicrosecondsDefault;

/// Default pause
const _cooperatorPauseMicrosecondsDefault = isRunningAsJavascript
    ? _cooperatorWebPauseMicrosecondsDefault
    : _cooperatorIoPauseMicrosecondsDefault;

/// Cooperator delay
var cooperatorDelayMicroseconds = _cooperatorDelayMicrosecondsDefault;

/// Cooperator pause
var cooperatorPauseMicroseconds = _cooperatorPauseMicrosecondsDefault;

/// Simple cooperate that checks every 4ms and wait for 100 microseconds.
///
/// While it degrades the performance (about 2%), it prevents heavy sort
/// algorithm from blocking the main isolate.
class Cooperator {
  /// True if activated.
  final bool cooperateOn = true;

  /// Timer.
  final _cooperateStopWatch = Stopwatch()..start();

  /// only the first one to pause handle this flag
  var _paused = false;

  /// Need to cooperate every 16 milliseconds.
  bool get needCooperate =>
      cooperateOn &&
      (_paused ||
          _cooperateStopWatch.elapsedMicroseconds >
              cooperatorDelayMicroseconds);

  /// pause
  Future<dynamic> get _pause =>
      Future.delayed(Duration(microseconds: cooperatorPauseMicroseconds));

  /// Cooperate if needed.
  FutureOr cooperate() {
    if (needCooperate) {
      var wasPaused = _paused;

      // Only the first one paused manipulate the stopwatch
      if (!wasPaused) {
        _paused = true;
        return _pause.then((_) {
          _cooperateStopWatch
            ..stop()
            ..reset()
            ..start();
          _paused = false;
        });
      } else {
        // We always pause additional requests
        return _pause;
      }
    } else {
      return null;
    }
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
bool cooperateNeeded(Cooperator? cooperator) =>
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
  globalCooperator.stop();
  cooperatorDisabled = true;
}

/// Re-enable sembast cooperator or change default pause and delay
///
/// [delayMicroseconds] specifies at which frequency an heavy algorithm is paused.
/// [pauseMicroseconds] specifies the duration of the pauseat which frequency an heavy algorithm is paused.
@visibleForTesting
void enableSembastCooperator({int? delayMicroseconds, int? pauseMicroseconds}) {
  cooperatorDisabled = false;
  cooperatorDelayMicroseconds =
      delayMicroseconds ?? _cooperatorDelayMicrosecondsDefault;
  cooperatorPauseMicroseconds =
      pauseMicroseconds ?? _cooperatorPauseMicrosecondsDefault;
  globalCooperator.restart();
}
