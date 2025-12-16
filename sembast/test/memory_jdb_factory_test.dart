library;

// basically same as the io runner but with extra output
import 'package:sembast/utils/jdb.dart';
import 'package:test/test.dart';

void main() {
  group('factory', () {
    var factory = databaseFactoryMemoryJdb;
    test('hasStorage', () async {
      expect(factory.hasStorage, true);
    });
  });
}
