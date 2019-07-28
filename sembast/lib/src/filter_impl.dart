import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/filter.dart';
import 'package:sembast/src/api/compat/record.dart';
import 'package:sembast/src/api/compat/sembast.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/record_snapshot_impl.dart';

// ignore_for_file: deprecated_member_use_from_same_package

// We can match if record is a map or if we are accessing the key or value
bool canMatch(String field, dynamic recordValue) =>
    (recordValue is Map) || (field == Field.value) || (field == Field.key);

/// Check if a [record] match a [filter]
bool filterMatchesRecord(Filter filter, RecordSnapshot record) {
  /// Allow raw access to record from within filters
  return (filter as SembastFilterBase)
      .matchesRecord(SembastRecordRawSnapshot(record));
}

abstract class SembastFilterBase implements Filter {
  bool matchesRecord(RecordSnapshot record);

  @override
  bool match(Record record) {
    if (record.deleted) {
      return false;
    }
    return matchesRecord(record);
  }
}

/// Custom filter
class SembastCustomFilter extends SembastFilterBase {
  final bool Function(RecordSnapshot record) matches;

  SembastCustomFilter(this.matches);

  @override
  bool matchesRecord(RecordSnapshot record) {
    try {
      /// Allow raw access
      return matches(record);
    } catch (_) {
      // Catch all exception
      return false;
    }
  }
}

mixin AnyInListMixin implements SembastFilterBase {
  bool anyInList;
}

mixin FilterValueMixin implements SembastFilterBase {
  dynamic value;
}

mixin FieldFieldMixin implements SembastFilterBase {
  String field;
}

/// Equals filter
class SembastEqualsFilter extends SembastFilterBase
    with AnyInListMixin, FilterValueMixin, FieldFieldMixin {
  SembastEqualsFilter(String field, dynamic value, bool anyInList) {
    this.field = field;
    this.value = value;
    this.anyInList = anyInList;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    if (!canMatch(field, record.value)) {
      return false;
    }
    var fieldValue = record[field];
    if (anyInList == true) {
      if (fieldValue is Iterable) {
        for (var itemValue in fieldValue) {
          if (itemValue == value) {
            return true;
          }
        }
      }
      return false;
    } else {
      return fieldValue == value;
    }
  }

  @override
  String toString() {
    return "${field} == ${value}";
  }
}

/// Equals filter
class SembastMatchesFilter extends SembastFilterBase
    with AnyInListMixin, FieldFieldMixin {
  final RegExp regExp;

  SembastMatchesFilter(String field, this.regExp, bool anyInList) {
    this.field = field;
    this.anyInList = anyInList;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    if (!canMatch(field, record.value)) {
      return false;
    }

    var fieldValue = record[field];

    bool _matches(dynamic value) {
      if (value is String) {
        return regExp.hasMatch(value);
      }
      return false;
    }

    if (anyInList == true) {
      if (fieldValue is Iterable) {
        for (var itemValue in fieldValue) {
          if (_matches(itemValue)) {
            return true;
          }
        }
      }
      return false;
    } else {
      return _matches(fieldValue);
    }
  }

  @override
  String toString() {
    return "${field} MATCHES ${regExp}";
  }
}

/// @deprecated v2
@deprecated
class SembastCompositeFilter extends SembastFilterBase {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  SembastCompositeFilter.or(this.filters) : isAnd = false;

  SembastCompositeFilter.and(this.filters) : isAnd = true;

  @override
  bool matchesRecord(RecordSnapshot record) {
    for (var filter in filters) {
      if ((filter as SembastFilterBase).matchesRecord(record)) {
        if (isOr) {
          return true;
        }
      } else {
        if (isAnd) {
          return false;
        }
      }
    }
    // if isOr, nothing has matches so far
    return isAnd;
  }

  @override
  String toString() {
    return filters.join(' ${isAnd ? "AND" : "OR"} ');
  }
}

class SembastFilterPredicate extends SembastFilterBase
    with FilterValueMixin, FieldFieldMixin {
  FilterOperation operation;

  SembastFilterPredicate(String field, this.operation, dynamic value) {
    this.field = field;
    this.value = value;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    int _safeCompare(dynamic value1, dynamic value2) {
      try {
        if (value1 is Comparable && value2 is Comparable) {
          return Comparable.compare(value1, value2);
        }
      } catch (_) {}
      return null;
    }

    bool _lessThan(dynamic value1, dynamic value2) {
      var cmp = _safeCompare(value1, value2);
      return cmp != null && cmp < 0;
    }

    bool _greaterThan(dynamic value1, dynamic value2) {
      var cmp = _safeCompare(value1, value2);
      return cmp != null && cmp > 0;
    }

    if (!canMatch(field, record.value)) {
      return false;
    }

    var fieldValue = record[field];
    switch (operation) {
      case FilterOperation.notEquals:
        return fieldValue != value;
      case FilterOperation.lessThan:
        // return _safeCompare(record[field], value) < 0;
        return _lessThan(fieldValue, value);
      case FilterOperation.lessThanOrEquals:
        return _lessThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) <= 0;
      case FilterOperation.greaterThan:
        return _greaterThan(fieldValue, value);
      // return _safeCompare(record[field], value) > 0;
      case FilterOperation.greaterThanOrEquals:
        return _greaterThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) >= 0;
      case FilterOperation.inList:
        return (value as List).contains(record[field]);
      default:
        throw "${this} not supported";
    }
  }

  @override
  String toString() {
    return "${field} ${operation} ${value}";
  }
}
