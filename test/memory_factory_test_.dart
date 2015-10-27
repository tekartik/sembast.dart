library sembast.test.memory_factory_test_;

import 'test_common.dart';
import 'all_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test('type', () {
    expect(
        memoryFileSystemContext.fs.runtimeType.toString(), "_MemoryFileSystem");
    expect(memoryDatabaseContext.factory,
        new isInstanceOf<MemoryDatabaseFactory>());
  });
  defineTests(memoryDatabaseContext);
}
