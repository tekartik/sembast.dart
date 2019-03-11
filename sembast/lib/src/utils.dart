import 'dart:collection';
import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

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

bool checkMapKey(key) {
  if (!(key is String)) {
    return false;
  }
  // Cannot contain .
  if ((key as String).contains('.')) {
    return false;
  }
  return true;
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

// default sort order
int compareKey(dynamic key1, dynamic key2) => compareValue(key1, key2);

int compareRecordKey(
        ImmutableSembastRecord record1, ImmutableSembastRecord record2) =>
    compareKey(record1.key, record2.key);

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

Map<String, dynamic> _fixMap(Map map) {
  var fixedMap = <String, dynamic>{};
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
  throw DatabaseException.badParam(
      "key ${key} not supported${key != null ? ' type:${key.runtimeType}' : ''}");
}

bool isValueMutable(dynamic value) {
  return value is Map || value is Iterable;
}

dynamic cloneValue(dynamic value) {
  if (value is Map) {
    return value.map<String, dynamic>(
        (key, value) => MapEntry(key as String, cloneValue(value)));
  }
  if (value is Iterable) {
    return value.map((value) => cloneValue(value)).toList();
  }
  if (value is String) {
    return value;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value;
  }
  if (value == null) {
    return value;
  }
  throw ArgumentError(
      "value ${value} not supported${value != null ? ' type:${value.runtimeType}' : ''}");
}

dynamic immutableValue(dynamic value) {
  if (value is Map) {
    return ImmutableMap<String, dynamic>(value);
  } else if (value is Iterable) {
    return ImmutableList(value);
  }
  return value;
}

class ImmutableList<E> extends ListBase<E> {
  final List<E> _list;

  @override
  int get length => _list.length;

  ImmutableList(Iterable<E> list) : _list = list.toList(growable: false);

  @override
  E operator [](int index) => immutableValue(_list[index]) as E;

  @override
  void operator []=(int index, value) => throw StateError('read only');

  @override
  set length(int newLength) => throw StateError('read only');
}

class ImmutableMap<K, V> extends MapBase<K, V> {
  final Map<K, V> _map;

  ImmutableMap(Map map) : _map = map.cast<K, V>();

  @override
  V operator [](Object key) => immutableValue(_map[key]) as V;

  @override
  void operator []=(K key, V value) => throw StateError('read only');

  @override
  void clear() => throw StateError('read only');

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V remove(Object key) => throw StateError('read only');
}

T getPartsMapValue<T>(Map map, Iterable<String> parts) {
  dynamic value = map;
  for (String part in parts) {
    if (value is Map) {
      value = value[part];
    } else {
      return null;
    }
  }
  return value as T;
}

void setPartsMapValue<T>(Map map, List<String> parts, value) {
  for (int i = 0; i < parts.length - 1; i++) {
    String part = parts[i];
    dynamic sub = map[part];
    if (!(sub is Map)) {
      sub = <String, dynamic>{};
      map[part] = sub;
    }
    map = sub as Map;
  }
  map[parts.last] = value;
}

List<String> getFieldParts(String field) => field.split('.');

T getMapFieldValue<T>(Map map, String field) {
  return getPartsMapValue(map, getFieldParts(field));
}

void setMapFieldValue(Map map, String field, dynamic value) {
  setPartsMapValue(map, getFieldParts(field), value);
}

// Merge an existing value with a new value, Map only!
dynamic mergeValue(dynamic existingValue, dynamic newValue) {
  if (newValue == null) {
    return existingValue;
  }

  if (!(existingValue is Map)) {
    return _fixValue(newValue);
  }
  if (!(newValue is Map)) {
    return newValue;
  }

  Map<String, dynamic> mergedMap =
      cloneValue(existingValue) as Map<String, dynamic>;
  Map currentMap = mergedMap;

  void merge(key, value) {
    // Handle a.b.c
    var keyParts = getFieldParts(key as String);
    if (keyParts.length == 1) {
      // delete the field?
      if (value == FieldValue.delete) {
        currentMap.remove(key);
      } else if (value is Map) {
        if (!(currentMap[key as String] is Map)) {
          // replace if existing is not a map
          currentMap[key as String] = value?.cast<String, dynamic>();
        } else {
          var previousMap = currentMap;
          currentMap =
              (currentMap[key as String] as Map)?.cast<String, dynamic>();
          value.forEach(merge);
          currentMap = previousMap;
        }
      } else {
        currentMap[key as String] = value;
      }
    } else {
      if (value == FieldValue.delete) {
        Map map = currentMap;
        for (String part in keyParts.sublist(0, keyParts.length - 1)) {
          dynamic sub = map[part];
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
        Map map = currentMap;
        for (String part in keyParts.sublist(0, keyParts.length - 1)) {
          dynamic sub = map[part];
          if (sub is Map) {
            map = sub;
          } else {
            // create sub part
            sub = <String, dynamic>{};
            map[part] = sub;
            map = sub as Map;
          }
        }
        var previousMap = currentMap;
        currentMap = map;
        merge(keyParts.last, value);
        currentMap = previousMap;
      }
    }
  }

  (newValue as Map).forEach(merge);
  return mergedMap;
}
