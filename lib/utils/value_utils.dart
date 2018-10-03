import 'package:sembast/src/utils.dart';

bool lessThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp < 0;
}

bool greaterThan(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp != null && cmp > 0;
}

// handle List too
bool equals(dynamic value1, dynamic value2) {
  var cmp = compareValue(value1, value2);
  return cmp == 0;
}
