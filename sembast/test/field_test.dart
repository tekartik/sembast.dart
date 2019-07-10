library sembast.field_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/api/sembast.dart';
import 'test_common.dart';

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
      expect(FieldKey.escape(null), isNull);
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
