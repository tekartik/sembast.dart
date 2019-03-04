import 'dart:async';

import 'package:sembast/sembast.dart';

///
/// Update all records matching [where] with the [values] fields
/// Returns the number of records updated
///
Future<int> updateRecords(StoreExecutor executor, Map<String, dynamic> values,
    {Finder where}) async {
  var records = await executor.findRecords(where);
  for (var record in records) {
    await executor.update(values, record.key);
  }
  return records.length;
}
