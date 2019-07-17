library sembast.test.memory_fs_factory_test_;

import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemoryFs;

import 'all_test.dart';
import 'fs_test_common.dart';
import 'test_common.dart';

// default use memory
void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "FileSystemMemory");
    expect(memoryFsDatabaseContext.factory,
        const TypeMatcher<DatabaseFactoryMemoryFs>());
    expect((databaseFactoryMemoryFs as DatabaseFactoryMemoryFs).fs,
        memoryFileSystemContext.fs);
  });

  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryFsDatabaseContext);
}
