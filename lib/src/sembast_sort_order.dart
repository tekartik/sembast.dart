part of sembast;

///
/// Sort order
///
class SortOrder {
  final bool ascending; // default true
  final String field;
  final bool nullLast; // default false

  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  SortOrder(this.field, [bool ascending, bool nullLast])
      : ascending = ascending != false,
        nullLast = nullLast == true;

  int compare(Record record1, Record record2) {
    int result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }

  int compareAscending(Record record1, Record record2) {
    var value1 = record1[field];
    var value2 = record2[field];
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
    return value1.compareTo(value2);
  }

  Map toDebugMap() {
    Map map = {field: ascending ? "asc" : "desc"};
    if (nullLast == true) {
      map['nullLast'] = true;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap.toString();
  }
}
