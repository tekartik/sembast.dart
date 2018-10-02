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
