import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/utils.dart' as utils;

/// Base sort order implementation.
abstract class SembastSortOrderBase<T extends Object?> implements SortOrder<T> {
  /// ascending.
  final bool ascending; // default true

  /// null last.
  final bool nullLast;

  /// Base sort order implementation.
  SembastSortOrderBase(this.ascending, this.nullLast); // default false

  /// Compare 2 records in ascending order.
  int compareAscending(RecordSnapshot record1, RecordSnapshot record2);

  /// Compare with a boundary in ascending order.
  int compareToBoundaryAscending(
      RecordSnapshot record, Boundary boundary, int index);

  /// Compare 2 record.
  int compare(RecordSnapshot record1, RecordSnapshot record2) {
    final result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }

  /// Compare a record to a boundary.
  int compareToBoundary(RecordSnapshot record, Boundary boundary, int index) {
    final result = compareToBoundaryAscending(record, boundary, index);
    return ascending ? result : -result;
  }

  /// Compare 2 values in ascending order.
  int compareValueAscending(Object? value1, Object? value2) {
    if (value1 == null) {
      if (value2 == null) {
        return 0;
      }
      if (nullLast) {
        return 1;
      } else {
        return -1;
      }
    } else if (value2 == null) {
      if (nullLast) {
        return -1;
      } else {
        return 1;
      }
    }
    return compareValue(value1, value2);
  }

  /// Compare 2 values. (overriden in custom sort order)
  int compareValue(Object value1, Object value2) {
    return utils.compareValue(value1, value2);
  }
}

/// Sort order implementation.
class SembastSortOrder<T extends Object?> extends SembastSortOrderBase<T> {
  /// field (key) name.
  final String field;

  ///
  /// default is [ascending] = true, [nullLast] = false
  ///
  /// user withParam
  SembastSortOrder(this.field, [bool? ascending, bool? nullLast])
      : super(ascending ?? true, nullLast ?? false);

  /// Compare a record to a snapshot.
  int compareToSnapshotAscending(
      RecordSnapshot record, RecordSnapshot snapshot) {
    var value1 = record[field];
    var value2 = snapshot[field];
    return compareValueAscending(value1, value2);
  }

  /// Compare a record to a boundary in ascending order.
  @override
  int compareToBoundaryAscending(
      RecordSnapshot record, Boundary boundary, int index) {
    final sembastBoundary = boundary as SembastBoundary;
    if (sembastBoundary.values != null) {
      var value = sembastBoundary.values![index];
      return compareValueAscending(record[field], value);
    } else if (sembastBoundary.snapshot != null) {
      return compareToSnapshotAscending(record, sembastBoundary.snapshot!);
    }
    throw ArgumentError('either record or values must be provided');
  }

  /// Compare 2 records in ascending order.
  @override
  int compareAscending(RecordSnapshot record1, RecordSnapshot record2) {
    var value1 = record1[field];
    var value2 = record2[field];
    return compareValueAscending(value1, value2);
  }

  Map<String, Object?> _toDebugMap() {
    final map = <String, Object?>{
      field: ascending ? 'asc' : 'desc',
      if (nullLast == true) 'nullLast': true
    };
    return map;
  }

  @override
  String toString() {
    return _toDebugMap().toString();
  }
}

/// Custom compare value function.
typedef SembastCustomSortOrderCompareFunction<T> = int Function(
    T value1, T value2);

/// Custom sort order compare function.
class SembastCustomSortOrder<T extends Object?> extends SembastSortOrder<T> {
  final SembastCustomSortOrderCompareFunction<T> _compare;

  /// Custom sort order compare function.
  SembastCustomSortOrder(
      String field, SembastCustomSortOrderCompareFunction<T> compare,
      [bool? ascending, bool? nullLast])
      : _compare = compare,
        super(field, ascending, nullLast);

  @override
  int compareValue(Object? value1, Object? value2) {
    return _compare(value1 as T, value2 as T);
  }
}
