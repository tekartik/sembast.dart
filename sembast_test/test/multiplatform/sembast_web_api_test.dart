@TestOn('vm || browser')
library sembast_web.test.sembast_web_api_test;

import 'package:sembast_web/sembast_web.dart';
import 'package:test/test.dart';

var testPath = '.dart_tool/sembast_test/sembas_io_api/databases';

Future main() async {
  group('sembast_web_api', () {
    test('databaseFactoryWeb', () async {
      try {
        databaseFactoryWeb;
      } on UnimplementedError catch (_) {
        // Web: UnimplementedError: databaseFactoryIo not supported on the web. use `sembast_web`
      }
    });
  });
}
