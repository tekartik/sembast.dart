import 'dart:async';

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/sembast.dart';

/// @deprecated v2
///
/// Update all records matching [where] with the [values] fields
/// Returns the number of records updated
///
@deprecated
Future<int> updateRecords(StoreExecutor executor, Map<String, dynamic> values,
    {Finder where}) async {
  var records = await executor.findRecords(where);
  for (var record in records) {
    await executor.update(values, record.key);
  }
  return records.length;
}
