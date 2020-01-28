import 'package:sembast/src/utils.dart';
import 'package:sembast/src/utils.dart' as utils;

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

/// Clone a map to make it writable.
///
/// This should be used to create a writable object that can be modified
Map<String, dynamic> cloneMap(Map<String, dynamic> value) =>
    cloneValue(value) as Map<String, dynamic>;

/// Clone a list to make it writable.
///
/// This should be used to create a writable object that can be modified
List<dynamic> cloneList(List<dynamic> value) =>
    cloneValue(value) as List<dynamic>;

/// Clone a value to make it writable, typically a list or a map.
///
/// Other supported object remains as is.
///
/// This should be used to create a writable object that can be modified.
dynamic cloneValue(dynamic value) => utils.cloneValue(value);
