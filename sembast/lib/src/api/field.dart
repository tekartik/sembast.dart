import 'package:sembast/src/utils.dart';

///
/// Special field access
///
class Field {
  /// Our value field
  static String value = '_value';

  /// Our key field
  static String key = '_key';
}

///
/// Update values
///
class FieldValue {
  final String _label;
  const FieldValue._(this._label);

  /// delete sentinel value
  static FieldValue delete = const FieldValue._('delete');

  @override
  String toString() => 'FieldValue.$_label';
}

///
/// Field Key utilities
///
class FieldKey {
  const FieldKey._();

  /// To use if you want to have dot in your field for update and filtering
  static String escape(String field) => escapeKey(field);
}
