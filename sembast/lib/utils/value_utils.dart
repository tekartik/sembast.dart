library sembast.utils.value_utils;

import 'package:sembast/src/utils.dart' as utils;

/// Clone a map to make it writable.
///
/// This should be used to create a writable object that can be modified
Map<String, Object?> cloneMap(Map value) =>
    cloneValue(value) as Map<String, Object?>;

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
