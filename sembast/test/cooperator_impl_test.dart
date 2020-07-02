import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/env_utils.dart';
import 'package:test/test.dart';

import 'test_common.dart';

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
  });
}
