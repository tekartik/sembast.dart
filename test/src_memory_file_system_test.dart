library sembast.io_file_system_test;

// basically same as the io runner but with extra output
import 'package:tekartik_test/test_config_io.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'src_file_system_test.dart' as fs;

void main() {
  useVMConfiguration();
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
