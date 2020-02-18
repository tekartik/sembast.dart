@TestOn('vm')
library sembast_test.test.io_factory_test;

import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/io_test_common.dart';
import 'package:test/test.dart';

import 'package:sembast_test/all_fs_test.dart' as all_fs_test;

void main() {
  var context = databaseContextIo;
  all_fs_test.defineTests(context);
  defineTests(databaseContextIo);
}
