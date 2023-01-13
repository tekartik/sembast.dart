library sembast.field_test;

import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

void main() {
  group('field', () {
    test('Field', () {
      expect(Field.key, '_key');
      expect(Field.value, '_value');
    });

    test('FieldValue', () {
      expect(FieldValue.delete, const TypeMatcher<FieldValue>());
    });

    test('FieldKey', () {
      expect(FieldKey.escape('``'), '````');
      expect(FieldKey.escape('`é`'), '``é``');
      expect(FieldKey.escape('```'), '`````');
      expect(FieldKey.escape('`'), '`');
      expect(FieldKey.escape('`_'), '`_');
      expect(FieldKey.escape('_`'), '_`');
      expect(FieldKey.escape('.'), '`.`');
      expect(FieldKey.escape('a'), 'a');
      expect(FieldKey.escape('a.'), '`a.`');
      expect(FieldKey.escape('.b'), '`.b`');
      expect(FieldKey.escape('a.b'), '`a.b`');
      expect(FieldKey.escape('a.b.c'), '`a.b.c`');
    });
  });
}
