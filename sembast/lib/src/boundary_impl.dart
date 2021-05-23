import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

/// Boundary implementation.
class SembastBoundary implements Boundary {
  /// The snapshot if any.
  final RecordSnapshot? snapshot;

  /// The values if any.
  List<Object?>? values;

  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  SembastBoundary({RecordSnapshot? record, bool? include, this.values})
      : include = include == true,
        snapshot = makeImmutableRecordSnapshot(record);

  Map<String, Object?> _toDebugMap() {
    final debugMap = <String, Object?>{};
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
    return _toDebugMap().toString();
  }

  @override
  bool include;
}
