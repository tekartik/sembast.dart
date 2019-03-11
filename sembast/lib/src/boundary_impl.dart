import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/boundary.dart';
import 'package:sembast/src/record_impl.dart';

class SembastBoundary implements Boundary {
  final RecordSnapshot snapshot;
  List<dynamic> values;

  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  SembastBoundary({RecordSnapshot record, bool include, this.values})
      : include = include == true,
        snapshot = makeImmutableRecordSnapshot(record);

  Map<String, dynamic> get _toDebugMap {
    Map<String, dynamic> debugMap = <String, dynamic>{};
    if (values != null) {
      debugMap['values'] = values.toString();
    } else if (snapshot != null) {
      debugMap['snapshot'] = snapshot.toString();
    }
    debugMap['include'] = include;
    return debugMap;
  }

  @override
  String toString() {
    // ignore: deprecated_member_use
    return _toDebugMap.toString();
  }

  @override
  bool include;
}
