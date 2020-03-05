library sembast.test.memory_factory_test;

// basically same as the io runner but with extra output
import 'package:sembast/src/memory/database_factory_memory.dart';
import 'package:test/test.dart';

void main() {
  group('factory', () {
    var factory = databaseFactoryMemoryJdb;
    test('hasStorage', () async {
      expect(factory.hasStorage, true);
    });
  });
}
