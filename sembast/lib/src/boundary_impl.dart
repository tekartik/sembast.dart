import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

class SembastBoundary implements Boundary {
  ImmutableSembastRecord record;
  List<dynamic> values;

  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  SembastBoundary({Record record, bool include, this.values})
      : include = include == true,
        record = makeImmutableRecord(record);

  Map<String, dynamic> get _toDebugMap {
    Map<String, dynamic> debugMap = <String, dynamic>{};
    if (record != null) {
      debugMap['record'] = record.toString();
    } else {
      debugMap['values'] = values.toString();
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
