library sembast.test.memory_fs_factory_test_;

import 'package:sembast/src/memory/database_factory_memory.dart'
    show DatabaseFactoryMemoryFs;
import 'package:sembast/sembast_memory.dart';

import 'all_test.dart';
import 'test_common.dart';

// default use memory
void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "_MemoryFileSystem");
    expect(memoryFsDatabaseContext.factory,
        const TypeMatcher<DatabaseFactoryMemoryFs>());
    expect((databaseFactoryMemoryFs as DatabaseFactoryMemoryFs).fs,
        memoryFileSystemContext.fs);
  });

  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryFsDatabaseContext);
}
