library sembast.test.memory_factory_test;

// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('factory', () {
    var factory = databaseFactoryMemory;
    test('hasStorage', () async {
      expect(factory.hasStorage, false);
    });
  });
}
