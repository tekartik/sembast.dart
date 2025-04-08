import 'package:meta/meta.dart';

bool _devPrintEnabled = true;

@Deprecated('Dev only')
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

/// Deprecated to prevent keeping the code used.
@doNotSubmit
void devPrint(Object object) {
  if (_devPrintEnabled) {
    // ignore: avoid_print
    print(object);
  }
}

/// Deprecated to prevent keeping the code used.
///
/// Can be use as a todo for weird code. int value = devWarning(myFunction());
/// The function is always called
@doNotSubmit
T devWarning<T>(T value) => value;

@doNotSubmit
/// Deprecated to prevent keeping the code used.
const bool devTrue = true;

@doNotSubmit
/// Deprecated to prevent keeping the code used.
const bool devFalse = false;
