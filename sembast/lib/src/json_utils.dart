import 'package:sembast/src/utils.dart';

extension _MapSorted on Map {
  bool isSorted() {
    return keys.isSorted();
  }
}

extension _ListSorted on Iterable {
  bool isSorted() {
    var first = true;
    late Comparable prev;
    for (var item in this) {
      if (first) {
        first = false;
      } else {
        if (prev.compareTo(item) > 0) {
          return false;
        }
      }
      prev = item as Comparable;
    }
    return true;
  }
}

/// Sort map elements
Map _jsonEncodableSortMap(Map map) {
  Map<String, Object?>? clone;
  map.forEach((key, item) {
    if (key is! String) {
      throw ArgumentError.value(key);
    }
    var converted = _jsonEncodableSort(item);
    if (!identical(converted, item)) {
      clone ??= Map<String, Object?>.from(map);
      clone![key] = converted;
    }
  });
  var result = clone ?? map;
  if (!result.isSorted()) {
    result = Map.fromEntries(map.entries.toList()
      ..sort((a, b) => (a.key as String).compareTo(b.key as String)));
  }
  return result;
}

/// Sort list elements
List _jsonEncodableSortList(List list) {
  List? clone;
  for (var i = 0; i < list.length; i++) {
    var item = list[i];
    var converted = _jsonEncodableSort(item);
    if (!identical(converted, item)) {
      clone ??= List.from(list);
      clone[i] = converted;
    }
  }
  return clone ?? list;
}

/// Sort map elements
Object? _jsonEncodableSort(Object? value) {
  if (isBasicTypeOrNull(value)) {
    return value;
  }

  if (value is Map) {
    return _jsonEncodableSortMap(value);
  } else if (value is List) {
    return _jsonEncodableSortList(value);
  } else {
    throw ArgumentError.value(value);
  }
}

/// Sort map or inner map elements alphabetically for a consistent json export.
Object jsonEncodableSort(Object value) {
  return _jsonEncodableSort(value)!;
}
