import 'package:sembast/src/utils.dart';

/// @deprecated v2
bool lessThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp < 0;
}

/// @deprecated v2
bool greaterThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp > 0;
}

/// @deprecated v2
bool equals(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp == 0;
}
