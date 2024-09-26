library;

import 'package:sembast/src/import_common.dart';
import 'package:sembast/src/utils.dart' as utils;

export 'package:sembast/src/json_utils.dart' show jsonEncodableSort;

/// Clone a map to make it writable.
///
/// This should be used to create a writable object that can be modified
Map<String, Object?> cloneMap(Map value) =>
    cloneValue(value) as Map<String, Object?>;

/// Clone a list to make it writable.
///
/// This should be used to create a writable object that can be modified
List<Object?> cloneList(List<Object?> value) =>
    cloneValue(value) as List<Object?>;

/// Clone a value to make it writable, typically a list or a map.
///
/// Other supported object remains as is.
///
/// This should be used to create a writable object that can be modified.
Value cloneValue(Value value) => utils.cloneValue(value);

/// Compare two values.
int valuesCompare(Object? value1, Object? value2) =>
    utils.compareValue(value1, value2);
