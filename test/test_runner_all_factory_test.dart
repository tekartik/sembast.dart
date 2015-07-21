@TestOn("vm")
library sembast.test_runner.all_test;

import 'package:test/test.dart';
import 'package:sembast/src/memory/memory_file_system.dart';
import 'package:sembast/src/io/io_file_system.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'test_runner_all_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast_io.dart';


// default use memory
void main() {
  //debugQuickLogging(Level.FINEST);
  group('memory', () {
    defineTests(memoryDatabaseFactory);
  });
  group('io', () {
    defineFileSystemTests(ioFileSystem);
    defineTests(ioDatabaseFactory);
  });
  group('memory_fs', () {
    defineFileSystemTests(memoryFileSystem);
    defineTests(new FsDatabaseFactory(memoryFileSystem));
  });
}
