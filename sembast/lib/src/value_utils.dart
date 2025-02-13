@Deprecated('Use valuesAreEquals')
/// Test where 2 values are equals, going deeper in lists and maps.
bool valueAreEquals(Object? value1, Object? value2) =>
    valuesAreEquals(value1, value2);

/// Test where 2 values are equals, going deeper in lists and maps
bool valuesAreEquals(Object? value1, Object? value2) {
  if (value1 == null) {
    return (value2 == null);
  } else if (value2 == null) {
    return false;
  }
  if (value1 is List) {
    if (value2 is List) {
      if (value1.length != value2.length) {
        return false;
      }
      for (var i = 0; i < value1.length; i++) {
        if (!valuesAreEquals(value1[i], value2[i])) {
          return false;
        }
      }
      return true;
    }
    return false;
  } else if (value1 is Map) {
    if (value2 is Map) {
      if (value1.length != value2.length) {
        return false;
      }
      for (var key in value1.keys) {
        if (!valuesAreEquals(value1[key], value2[key])) {
          return false;
        }
      }
      return true;
    }
  }
  return value1 == value2;
}
