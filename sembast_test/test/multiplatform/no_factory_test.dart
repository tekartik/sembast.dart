import 'package:test/test.dart';
import 'package:sembast_test/field_test.dart' as field_test;
import 'package:sembast_test/utils_test.dart' as utils_test;
import 'package:sembast_test/value_utils_test.dart' as value_utils_test;
import 'package:sembast_test/doc_unit_test.dart' as doc_unit_test;

void main() {
  group('no factory', () {
    field_test.main();
    utils_test.main();
    value_utils_test.main();
    doc_unit_test.main();
  });
}
