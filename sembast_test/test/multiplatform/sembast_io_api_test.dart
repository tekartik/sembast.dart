@TestOn('vm || browser')
library sembast_web.test.sembast_io_api_test;

import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_test/sembas_io_api/databases';

Future main() async {
  group('sembast_io_api', () {
    test('open', () async {
      try {
        databaseFactoryIo;
      } on UnimplementedError catch (_) {
        // Web: UnimplementedError: databaseFactoryIo not supported on the web. use `sembast_web`
      }
    });
    test('open', () async {
      try {
        createDatabaseFactoryIo;
      } on UnimplementedError catch (_) {
        // Web: UnimplementedError: databaseFactoryIo not supported on the web. use `sembast_web`
      }
    });
  });
}
