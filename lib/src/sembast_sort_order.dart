part of sembast;

///
/// Sort order
/// 
class SortOrder {
  final bool ascending;
  final String field;

  ///
  /// default is [ascending] = true
  ///
  SortOrder(this.field, [bool ascending]) : ascending = ascending != false;
  int compare(Record record1, Record record2) {
    int result = compareAscending(record1, record2);
    return ascending ? result : -result;
  }
  int compareAscending(Record record1, Record record2) {
    var value1 = record1[field];
    var value2 = record2[field];
    if (value1 == null) {
      return -1;
    } else if (value2 == null) {
      return 1;
    }
    return value1.compareTo(value2);
  }

  Map toDebugMap() {
    return {
      field: ascending ? "asc" : "desc"
    };
  }

  @override
  String toString() {
    return "${field} ${ascending ? 'asc' : 'desc'}";
  }
}
