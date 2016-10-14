library sembast.test.memory_fs_factory_test_;

import 'all_test.dart';
import 'test_common.dart';
import 'package:sembast/sembast_memory.dart';

// default use memory
void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "_MemoryFileSystem");
    expect(memoryFsDatabaseContext.factory,
        new isInstanceOf<MemoryFsDatabaseFactory>());
    expect(memoryFsDatabaseFactory.fs, memoryFileSystemContext.fs);
  });

  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryFsDatabaseContext);
}
