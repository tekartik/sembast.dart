import 'dart:math';
import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/immutable_utils.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/timestamp_impl.dart';

import 'import_common.dart';

// compat
export 'package:sembast/src/immutable_utils.dart';

/// Backtick char code.
final backtickChrCode = '`'.codeUnitAt(0);

/// Check keys.
bool checkMapKey(Object? key) {
  if (key is! String) {
    return false;
  }
  // Cannot contain .
  if (key.contains('.')) {
    return false;
  }
  return true;
}

/// Check a value.
bool checkValue(Object? value) {
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
      if (!checkMapKey(entry.key)) {
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

/// default sort order
int compareKey(dynamic key1, dynamic key2) => compareValue(key1, key2);

/// compare record keys.
int compareRecordKey(
        ImmutableSembastRecord record1, ImmutableSembastRecord record2) =>
    compareKey(record1.key, record2.key);

/// Compare 2 values.
///
/// return <0 if value1 < value2 or >0 if greater
/// returns null if cannot be compared.
///
/// Follows firestore ordering:
/// https://firebase.google.com/docs/firestore/manage-data/data-types
///
/// Value type ordering (field with values of mixed types, The following list shows the order):
/// - Null values
/// - Boolean values
/// - Integer and floating-point values, sorted in numerical order
/// - Timestamp values
/// - Text string values
/// - Blob values
/// - List values
/// - Map values
int compareValue(dynamic value1, dynamic value2) {
  try {
    if (value1 is Comparable && value2 is Comparable) {
      return Comparable.compare(value1, value2);
    } else if (value1 is List && value2 is List) {
      final list1 = value1;
      final list2 = value2;

      for (var i = 0; i < min(value1.length, value2.length); i++) {
        final cmp = compareValue(list1[i], list2[i]);
        if (cmp == 0) {
          continue;
        }
        return cmp;
      }
      // Same ? return the length diff if any
      return compareValue(list1.length, list2.length);
    } else if (value1 is bool && value2 is bool) {
      return compareBool(value1, value2);
    }
  } catch (_) {
    // Handle null and various exception not handled
  }
  // Compare value type
  var cmp = compareValueType(value1, value2);

  return cmp;
}

/// Compare 2 boolean: fase < null
int compareBool(bool value1, bool value2) {
  if (value1) {
    if (value2) {
      return 0;
    }
    return 1;
  }
  return value2 ? -1 : 0;
}

/// Compare 2 value types.
///
/// return <0 if value1 < value2 or >0 if greater
///
/// Follows firestore ordering:
/// https://firebase.google.com/docs/firestore/manage-data/data-types
///
/// Value type ordering (field with values of mixed types, The following list shows the order):
/// - Null values
/// - Boolean values
/// - Integer and floating-point values, sorted in numerical order
/// - Timestamp values
/// - Text string values
/// - Blob values
/// - List values
/// - Map values
int compareValueType(dynamic value1, dynamic value2) {
  // first null
  if (value1 == null) {
    if (value2 == null) {
      return 0;
    } else {
      // null first
      return -1;
    }
  } else if (value2 == null) {
    return 1;
  } else if (value1 is bool) {
    // then bool
    if (value2 is bool) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is bool) {
    return 1;
  } else if (value1 is num) {
    // then num
    if (value2 is num) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is num) {
    return 1;
  } else if (value1 is Timestamp) {
    // then timestamp
    if (value2 is Timestamp) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is Timestamp) {
    return 1;
  } else if (value1 is String) {
    // then timestamp
    if (value2 is String) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is String) {
    return 1;
  } else if (value1 is Blob) {
    // then timestamp
    if (value2 is Blob) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is Blob) {
    return 1;
  } else if (value1 is List) {
    // then timestamp
    if (value2 is List) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is List) {
    return 1;
  } else if (value1 is Map) {
    // then timestamp
    if (value2 is List) {
      return 0;
    } else {
      return -1;
    }
  } else if (value2 is Map) {
    return 1;
  }

  /// Convert to string in the worst case
  return compareValue(value1.toString(), value2.toString());
}

Map<String, Object?> _fixMap(Map map) {
  var fixedMap = <String, Object?>{};
  map.forEach((key, value) {
    if (value != FieldValue.delete) {
      fixedMap[key as String] = _fixValue(value);
    }
  });
  return fixedMap;
}

dynamic _fixValue(dynamic value) {
  if (value is Map) {
    return _fixMap(value);
  }
  return value;
}

/// Clone a key.
K cloneKey<K>(K key) {
  if (key is String) {
    return key;
  }
  if (key is num) {
    return key;
  }
  if (key == null) {
    return key;
  }
  throw DatabaseException.badParam('key $key not supported ${key.runtimeType}');
}

/// Clone a value.
Value cloneValue(Value value) {
  if (value is Map) {
    return value.map<String, Object?>(
        (key, value) => MapEntry(key as String, cloneValueOrNull(value)));
  }
  if (value is Iterable) {
    return value.map((value) => cloneValueOrNull(value)).toList();
  }
  return value;
}

/// Clone a value.
dynamic cloneValueOrNull(dynamic value) {
  if (value is Map) {
    return value.map<String, Object?>(
        (key, value) => MapEntry(key as String, cloneValueOrNull(value)));
  }
  if (value is Iterable) {
    return value.map((value) => cloneValueOrNull(value)).toList();
  }
  return value;
}

/// Sanitize Map type for root value
Object sanitizeValueIfMap(Object value) {
  if (value is Map) {
    if (value is! Map<String, Object?>) {
      return value.cast<String, Object?>();
    }
  }
  return value;
}

/// True for null, num, String, bool
bool isBasicTypeOrNull(dynamic value) {
  if (value == null) {
    return true;
  } else if (value is num || value is String || value is bool) {
    return true;
  }
  return false;
}

/// True for null, num, String, bool or FieldValue
bool isBasicTypeFieldValueOrNull(dynamic value) {
  if (isBasicTypeOrNull(value)) {
    return true;
  } else if (value is FieldValue) {
    return true;
  }
  return false;
}

/// Get value at a given field path.
///
/// Handle index for iterables
T? getPartsMapValue<T>(Map map, Iterable<String> parts) {
  Object? value = map;
  for (final part in parts) {
    if (value is Map) {
      value = value[part];
    } else if (value is List) {
      var index = int.tryParse(part) ?? -1;
      if (index >= 0 && index < value.length) {
        value = value[index];
      }
    } else {
      return null;
    }
  }
  return value as T?;
}

/// Smart match function
typedef SmartMatchValueFunction = bool Function(Object? value);

/// Wild card for index
const smartMatchIndexWildcard = '@';
bool _smartMatchPartsAnyValue(Object? value, String part,
    Iterable<String> parts, SmartMatchValueFunction match) {
  bool matchItem(Object? item) {
    if (parts.isEmpty) {
      return match(item);
    } else {
      return _smartMatchPartsAnyValue(item, parts.first, parts.skip(1), match);
    }
  }

  if (value is List) {
    if (part == smartMatchIndexWildcard) {
      for (var item in value) {
        if (matchItem(item)) {
          return true;
        }
      }
      return false;
    } else {
      var itemIndex = int.tryParse(part) ?? -1;
      if (itemIndex >= 0 && itemIndex < value.length) {
        var item = value[itemIndex];
        return matchItem(item);
      }
      return false;
    }
  } else if (value is Map) {
    var item = value[part];
    return matchItem(item);
  }
  return false;
}

/// Check a value at a given field map
/// Handle @ for any item in list
bool smartMatchPartsMapValue(
    Map map, Iterable<String> parts, SmartMatchValueFunction match) {
  if (parts.isEmpty) {
    return false;
  }
  return _smartMatchPartsAnyValue(map, parts.first, parts.skip(1), match);
}

/// Get a raw value at a given field path. Content is mutable so to use
/// internally only.
T? getPartsMapRawValue<T>(Map map, Iterable<String> parts) {
  // Allow getting raw value
  if (map is ImmutableMap) {
    map = map.rawMap;
  }
  return getPartsMapValue(map, parts);
}

/// Set value at a given field path.
void setPartsMapValue<T>(Map map, List<String> parts, T value) {
  for (var i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    dynamic sub = map[part];
    if (sub is! Map) {
      sub = <String, Object?>{};
      map[part] = sub;
    }
    map = sub;
  }
  map[parts.last] = value;
}

/// Check if a trick is enclosed by backticks
bool isBacktickEnclosed(String field) {
  final length = field.length;
  if (length < 2) {
    return false;
  }
  return field.codeUnitAt(0) == backtickChrCode &&
      field.codeUnitAt(length - 1) == backtickChrCode;
}

String _escapeKey(String field) => '`$field`';

/// Escape a key.
String? escapeKey(String? field) {
  if (field == null) {
    return null;
  }
  if (isBacktickEnclosed(field)) {
    return _escapeKey(field);
  } else if (field.contains('.')) {
    return _escapeKey(field);
  }
  return field;
}

String _unescapeKey(String field) => field.substring(1, field.length - 1);

/// For merged values and filters
List<String> getFieldParts(String field) {
  if (isBacktickEnclosed(field)) {
    return [_unescapeKey(field)];
  }
  return getRawFieldParts(field);
}

/// Get field segments.
List<String> getRawFieldParts(String field) => field.split('.');

/// Get field value.
T? getMapFieldValue<T>(Map map, String field) {
  return getPartsMapValue(map, getFieldParts(field));
}

/// Avoid immutable map duplication
T? getMapFieldRawValue<T>(Map map, String field) {
  return getPartsMapRawValue(map, getFieldParts(field));
}

/// Set a field value.
void setMapFieldValue<T>(Map map, String field, T value) {
  setPartsMapValue(map, getFieldParts(field), value);
}

/// Merge an existing value with a new value, Map only
///
/// either [existingValue] or [newValue] must not be null
Object mergeValue(Object? existingValue, Object? newValue,
    {bool? allowDotsInKeys}) {
  // both cannot be null.
  assert(existingValue != null || newValue != null);
  allowDotsInKeys ??= false;

  if (newValue == null) {
    return existingValue!;
  }

  if (existingValue is! Map) {
    return _fixValue(newValue) as Object;
  }
  if (newValue is! Map) {
    return newValue;
  }

  final mergedMap = cloneValue(existingValue) as Map<String, Object?>;
  Map? currentMap = mergedMap;

  // Here we have the new key and values to merge
  void merge(Key? key, Value? value) {
    var stringKey = key as String;
    // Handle a.b.c or `` `a.b.c` ``
    List<String> keyParts;
    if (allowDotsInKeys!) {
      keyParts = [stringKey];
    } else {
      keyParts = getFieldParts(stringKey);
    }
    if (keyParts.length == 1) {
      stringKey = keyParts[0];
      // delete the field?
      if (value == FieldValue.delete) {
        currentMap!.remove(stringKey);
      } else {
        // Replace the content. We don't want to merge here since we are the
        // last part of the path specification
        currentMap![stringKey] = value;
      }
    } else {
      if (value == FieldValue.delete) {
        var map = currentMap;
        for (var part in keyParts.sublist(0, keyParts.length - 1)) {
          dynamic sub = map![part];
          if (sub is Map) {
            map = sub;
          } else {
            map = null;
            break;
          }
        }
        if (map != null) {
          map.remove(keyParts.last);
        }
      } else {
        var map = currentMap;
        for (final part in keyParts.sublist(0, keyParts.length - 1)) {
          dynamic sub = map![part];
          if (sub is Map) {
            map = sub;
          } else {
            // create sub part
            sub = <String, Object?>{};
            map[part] = sub;
            map = sub;
          }
        }
        var previousMap = currentMap;
        currentMap = map;
        merge(keyParts.last, value);
        currentMap = previousMap;
      }
    }
  }

  newValue.forEach(merge);
  return mergedMap;
}

// 2.5 compatibility change
//
// TODO 2019/07/08 This could be removed once the stable API returns Uint8List everywhere
/// Tmp 2.5 compatibility change
Stream<Uint8List> intListStreamToUint8ListStream(Stream stream) {
  if (stream is Stream<Uint8List>) {
    return stream;
  } else if (stream is Stream<List<int>>) {
    return stream.transform(
        StreamTransformer<List<int>, Uint8List>.fromHandlers(
            handleData: (list, sink) {
      sink.add(Uint8List.fromList(list));
    }));
  } else {
    throw ArgumentError('Invalid stream type: ${stream.runtimeType}');
  }
}
