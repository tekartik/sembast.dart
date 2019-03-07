///
/// Special field access
///
class Field {
  /// Our value field
  static String value = "_value";

  /// Our key field
  static String key = "_key";
}

///
/// Update values
///
class FieldValue {
  const FieldValue._();
  static FieldValue delete = const FieldValue._();
}
