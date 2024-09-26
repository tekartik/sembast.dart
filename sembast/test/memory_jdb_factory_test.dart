library;

// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('factory', () {
    var factory = databaseFactoryMemoryFs;
    test('hasStorage', () async {
      expect(factory.hasStorage, true);
    });
  });
}
