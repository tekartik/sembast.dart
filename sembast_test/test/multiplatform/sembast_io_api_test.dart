@TestOn('vm || browser')
library;

import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/env_utils.dart' show isRunningAsJavascript;
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_test/sembas_io_api/databases';

Future main() async {
  group('sembast_io_api', () {
    test('open', () async {
      try {
        databaseFactoryIo;
        expect(isRunningAsJavascript, isFalse);
      } on UnimplementedError catch (_) {
        // Web: UnimplementedError: databaseFactoryIo not supported on the web. use `sembast_web`
      }
    });
    test('open', () async {
      try {
        createDatabaseFactoryIo();
        expect(isRunningAsJavascript, isFalse);
      } on UnimplementedError catch (_) {
        // Web: UnimplementedError: databaseFactoryIo not supported on the web. use `sembast_web`
      }
    });
  });
}
