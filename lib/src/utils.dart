import 'dart:math';

dynamic sanitizeValue(value) {
  if (value == null) {
    return null;
  } else if (value is num || value is String || value is bool) {
    return value;
  } else if (value is List) {
    return value;
  } else if (value is Map) {
    // We force the value map type for easy usage
    return value.cast<String, dynamic>();
  }
  throw ArgumentError.value(
      value, null, "type ${value.runtimeType} not supported");
}

bool checkValue(value) {
  if (value == null) {
    return true;
  } else if (value is num || value is String || value is bool) {
    return true;
  } else if (value is List) {
    for (var item in value) {
      if (!checkValue(item)) {
        return false;
      }
    }
    return true;
  } else if (value is Map) {
    for (var entry in value.entries) {
      if (!(entry.key is String)) {
        return false;
      }
      if (!checkValue(entry.value)) {
        return false;
      }
    }
    return true;
  } else {
    return false;
  }
}

// return <0 if value1 < value2 or >0 if greater
// returns null if cannot be compared
int compareValue(dynamic value1, dynamic value2) {
  try {
    if (value1 is Comparable && value2 is Comparable) {
      return Comparable.compare(value1, value2);
    } else if (value1 is List && value2 is List) {
      List list1 = value1;
      List list2 = value2;

      for (int i = 0; i < min(value1.length, value2.length); i++) {
        int cmp = compareValue(list1[i], list2[i]);
        if (cmp == 0) {
          continue;
        }
        return cmp;
      }
      // Same ? return the length diff if any
      return compareValue(list1.length, list2.length);
    }
  } catch (_) {}
  return null;
}
