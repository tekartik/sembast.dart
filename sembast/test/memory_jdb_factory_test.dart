library sembast.test.memory_fs_factory_test_;

import 'package:sembast/src/api/v2/sembast_memory.dart'; // ignore: implementation_imports
import 'package:sembast/src/memory/database_factory_memory.dart' // ignore: implementation_imports
    show
        DatabaseFactoryMemoryJdb;

import 'all_test.dart';
import 'jdb_test_common.dart';
import 'test_common.dart';

// default use memory
void main() {
  test('type', () {
    expect(databaseTestContextJdbMemory.jdbFactory.runtimeType.toString(),
        'JdbFactoryMemory');
    expect(databaseTestContextJdbMemory.factory,
        const TypeMatcher<DatabaseFactoryMemoryJdb>());
    expect((databaseFactoryMemoryJdb as DatabaseFactoryMemoryJdb).jdbFactory,
        databaseTestContextJdbMemory.jdbFactory);
  });

  // defineFileSystemTests(memoryFileSystemContext);
  defineTests(databaseTestContextJdbMemory);
}
