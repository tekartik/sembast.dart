library sembast.io_file_system_test;

// basically same as the io runner but with extra output
import 'package:test/test.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'test_runner_src_file_system.dart' as fs;

void main() {
  //useVMConfiguration();
  defineTests();
}

void defineTests() {

  group('memory', () {

    setUp(() {
    });

    tearDown(() {
    });

    
  });
  
  fs.defineTests(memoryFileSystem);
}
