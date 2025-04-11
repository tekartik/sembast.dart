import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/value_utils.dart';

import 'import_common.dart';
import 'utils.dart';

/// We can match if record is a map or if we are accessing the key or value
bool canMatch(String? field, dynamic recordValue) =>
    (recordValue is Map) || (field == Field.value) || (field == Field.key);

/// Check if a [record] match a [filter]
bool filterMatchesRecord(Filter? filter, RecordSnapshot record) {
  if (filter == null) {
    return true;
  }

  /// Allow raw access to record from within filters
  return (filter as SembastFilterBase).matchesRecord(
    SembastRecordRawSnapshot(record),
  );
}

/// Sembast filter.
abstract interface class SembastFilter implements Filter {
  /// True if the record matches.
  bool matchesRecord(RecordSnapshot record);
}

/// Filter base.
abstract class SembastFilterBase implements SembastFilter {
  /// True if the record matches.
  @override
  bool matchesRecord(RecordSnapshot record);
}

/// Custom filter
class SembastCustomFilter extends SembastFilterBase {
  /// matches custom filter.
  final bool Function(RecordSnapshot record) matches;

  /// Custom filter.
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

  @override
  String toString() => 'SembastCustomFilter()';
}

abstract class _FilterAnyInList {
  bool? get anyInList;
}

abstract class _FilterValue {
  Object? get value;
}

abstract class _FilterField {
  String get field;
}

/// Any in list mixin.
mixin FilterAnyInListMixin implements SembastFilterBase, _FilterAnyInList {
  /// True if it should match any in a list.
  @override
  bool? anyInList;
}

/// Value mixin.
mixin FilterValueMixin implements SembastFilterBase, _FilterValue {
  /// The value.
  @override
  late Object? value;
}

/// Field information (name) mixin
mixin FilterFieldMixin implements SembastFilterBase, _FilterField {
  /// The field.
  @override
  late String field;
}

mixin _FilterSmartMatchMixin implements _FilterAnyInList, _FilterField {
  bool smartMatchesRecord(
    RecordSnapshot record,
    SmartMatchValueFunction match,
  ) {
    var field = this.field;
    final recordValue = record.value;
    if (!canMatch(field, recordValue)) {
      return false;
    }
    // for key and value) {

    bool matchValue(Object? value) {
      if (anyInList ?? false) {
        if (value is Iterable) {
          for (var itemValue in value) {
            if (match(itemValue)) {
              return true;
            }
          }
        }
        return false;
      }
      return match(value);
    }

    if (field == Field.value) {
      return matchValue(recordValue);
    } else if (field == Field.key) {
      return matchValue(record.key);
    } else {
      // Compat.
      if (anyInList == true) {
        field = '$field.$smartMatchIndexWildcard';
      }
      // We know it is a map here
      return smartMatchPartsMapValue(
        recordValue as Map,
        getFieldParts(field),
        match,
      );
    }
  }
}

/// Equals filter.
class SembastEqualsFilter extends SembastFilterBase
    with
        FilterAnyInListMixin,
        FilterValueMixin,
        FilterFieldMixin,
        _FilterSmartMatchMixin {
  /// Equals filter.
  SembastEqualsFilter(String field, dynamic value, bool? anyInList) {
    this.field = field;
    this.value = value;
    this.anyInList = anyInList;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    // Special null handling
    if (value == null) {
      return record[field] == null;
    }
    bool match(Object? value) => valuesAreEquals(value, this.value);
    return smartMatchesRecord(record, match);
  }

  @override
  String toString() {
    return '$field == $value';
  }
}

/// List filter options.
enum SembastListFilterOptions {
  /// Contains filter.
  contains,

  /// Contains all filter.
  containsAll,

  /// Contains any filter.
  containsAny,
}

/// Equals filter.
class SembastListFilter extends SembastFilterBase
    with FilterValueMixin, FilterFieldMixin {
  /// The list filter options.
  final SembastListFilterOptions options;

  /// The list of values for any and all
  List get values => (value as List);

  /// Equals filter.
  SembastListFilter(String field, Object value, this.options) {
    this.field = field;
    this.value = value;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    var existingValue = record[field];
    if (existingValue is! List) {
      return false;
    }
    switch (options) {
      case SembastListFilterOptions.contains:
        return existingValue.contains(value);
      case SembastListFilterOptions.containsAll:
        return values.every((element) => existingValue.contains(element));
      case SembastListFilterOptions.containsAny:
        return values.any((element) => existingValue.contains(element));
    }
  }

  @override
  String toString() {
    return '$field ${options.name.split('.').last} $value';
  }
}

/// Not equals filter.
class SembastNotEqualsFilter extends SembastEqualsFilter {
  /// Not equals filter.
  SembastNotEqualsFilter(super.field, Value? super.value, super.anyInList);

  @override
  bool matchesRecord(RecordSnapshot record) => !super.matchesRecord(record);

  @override
  String toString() {
    return '$field != $value';
  }
}

/// Matches filter.
class SembastMatchesFilter extends SembastFilterBase
    with FilterAnyInListMixin, FilterFieldMixin, _FilterSmartMatchMixin {
  /// The regular expression.
  final RegExp regExp;

  /// Matches filter.
  SembastMatchesFilter(String field, this.regExp, bool? anyInList) {
    this.field = field;
    this.anyInList = anyInList;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    bool match(Object? value) {
      if (value is String) {
        return regExp.hasMatch(value);
      }
      return false;
    }

    return smartMatchesRecord(record, match);
  }

  @override
  String toString() {
    return '$field MATCHES $regExp';
  }
}

/// Composite filter
class SembastCompositeFilter extends SembastFilterBase {
  // ignore: public_member_api_docs
  bool isAnd; // if false it is OR
  // ignore: public_member_api_docs
  bool get isOr => !isAnd;

  // ignore: public_member_api_docs
  List<Filter> filters;

  // ignore: public_member_api_docs
  SembastCompositeFilter.or(this.filters) : isAnd = false;

  // ignore: public_member_api_docs
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
    return filters.join(' ${isAnd ? 'AND' : 'OR'} ');
  }
}

/// Opposite filter
class SembastOppositeFilter extends SembastFilterBase {
  // ignore: public_member_api_docs
  Filter filter;

  // ignore: public_member_api_docs
  SembastOppositeFilter(this.filter);

  @override
  bool matchesRecord(RecordSnapshot record) {
    return !(filter as SembastFilterBase).matchesRecord(record);
  }

  @override
  String toString() {
    return 'NOT $filter';
  }
}

/// Filter predicate implementation.
class SembastFilterPredicate extends SembastFilterBase
    with FilterValueMixin, FilterFieldMixin {
  /// The operation.
  FilterOperation operation;

  /// Filter predicate implementation.
  SembastFilterPredicate(String field, this.operation, dynamic value) {
    this.field = field;
    this.value = value;
  }

  @override
  bool matchesRecord(RecordSnapshot record) {
    int? safeCompare(dynamic value1, dynamic value2) {
      try {
        if (value1 is Comparable && value2 is Comparable) {
          return Comparable.compare(value1, value2);
        }
      } catch (_) {}
      return null;
    }

    bool lessThan(dynamic value1, dynamic value2) {
      var cmp = safeCompare(value1, value2);
      return cmp != null && cmp < 0;
    }

    bool greaterThan(dynamic value1, dynamic value2) {
      var cmp = safeCompare(value1, value2);
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
        return lessThan(fieldValue, value);
      case FilterOperation.lessThanOrEquals:
        return lessThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) <= 0;
      case FilterOperation.greaterThan:
        return greaterThan(fieldValue, value);
      // return _safeCompare(record[field], value) > 0;
      case FilterOperation.greaterThanOrEquals:
        return greaterThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) >= 0;
      case FilterOperation.inList:
        return (value as List).contains(record[field]);
      default:
        throw '$this not supported';
    }
  }

  @override
  String toString() {
    return '$field $operation $value';
  }
}

/// Filter operation
class FilterOperation {
  /// Value to compare
  final int value;

  const FilterOperation._(this.value);

  /// equal filter
  static const FilterOperation equals = FilterOperation._(1);

  /// not equal filter
  static const FilterOperation notEquals = FilterOperation._(2);

  /// less then filter
  static const FilterOperation lessThan = FilterOperation._(3);

  /// less than or equals filter
  static const FilterOperation lessThanOrEquals = FilterOperation._(4);

  /// greater than filter
  static const FilterOperation greaterThan = FilterOperation._(5);

  /// greater than or equals filter
  static const FilterOperation greaterThanOrEquals = FilterOperation._(6);

  /// in list filter
  static const FilterOperation inList = FilterOperation._(7);

  /// matches filter
  static const FilterOperation matches = FilterOperation._(8);

  @override
  String toString() {
    switch (this) {
      case FilterOperation.equals:
        return '=';
      case FilterOperation.notEquals:
        return '!=';
      case FilterOperation.lessThan:
        return '<';
      case FilterOperation.lessThanOrEquals:
        return '<=';
      case FilterOperation.greaterThan:
        return '>';
      case FilterOperation.greaterThanOrEquals:
        return '>=';
      case FilterOperation.inList:
        return 'IN';
      case FilterOperation.matches:
        return 'MATCHES';
      default:
        throw '$this not supported';
    }
  }
}
