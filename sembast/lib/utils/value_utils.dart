import 'package:sembast/src/utils.dart';

/// @deprecated v2
@deprecated
bool lessThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp < 0;
}

/// @deprecated v2
@deprecated
bool greaterThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp > 0;
}

/// @deprecated v2
@deprecated
bool equals(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp == 0;
}

/// Clone a value to make it writable, typically a map
///
/// This should be used to create a writable object that can be modified
Map<String, dynamic> cloneMap(Map<String, dynamic> value) =>
    cloneValue(value) as Map<String, dynamic>;
