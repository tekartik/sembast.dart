import 'package:sembast/sembast.dart';

class CompositeFilter extends Filter {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  CompositeFilter.or(this.filters) : isAnd = false;

  CompositeFilter.and(this.filters) : isAnd = true;

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }

    for (Filter filter in filters) {
      if (filter.match(record)) {
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

class FilterPredicate extends Filter {
  String field;
  FilterOperation operation;
  var value;

  FilterPredicate(this.field, this.operation, this.value) : super();

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }

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

    // empty record or not map? refuse
    if ((!(record.value is Map)) &&
        (field != Field.value && field != Field.key)) {
      return false;
    }

    var fieldValue = record[field];
    switch (operation) {
      case FilterOperation.EQUAL:
        return fieldValue == value;
      case FilterOperation.NOT_EQUAL:
        return fieldValue != value;
      case FilterOperation.LESS_THAN:
        // return _safeCompare(record[field], value) < 0;
        return _lessThan(fieldValue, value);
      case FilterOperation.LESS_THAN_OR_EQUAL:
        return _lessThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) <= 0;
      case FilterOperation.GREATER_THAN:
        return _greaterThan(fieldValue, value);
      // return _safeCompare(record[field], value) > 0;
      case FilterOperation.GREATER_THAN_OR_EQUAL:
        return _greaterThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) >= 0;
      case FilterOperation.IN:
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

class FilterOperation {
  final int value;

  const FilterOperation._(this.value);

  static const FilterOperation EQUAL = FilterOperation._(1);
  static const FilterOperation NOT_EQUAL = FilterOperation._(2);
  static const FilterOperation LESS_THAN = FilterOperation._(3);
  static const FilterOperation LESS_THAN_OR_EQUAL = FilterOperation._(4);
  static const FilterOperation GREATER_THAN = FilterOperation._(5);
  static const FilterOperation GREATER_THAN_OR_EQUAL = FilterOperation._(6);
  static const FilterOperation IN = FilterOperation._(7);

  @override
  String toString() {
    switch (this) {
      case FilterOperation.EQUAL:
        return "=";
      case FilterOperation.NOT_EQUAL:
        return "!=";
      case FilterOperation.LESS_THAN:
        return "<";
      case FilterOperation.LESS_THAN_OR_EQUAL:
        return "<=";
      case FilterOperation.GREATER_THAN:
        return ">";
      case FilterOperation.GREATER_THAN_OR_EQUAL:
        return ">=";
      case FilterOperation.IN:
        return "IN";
      default:
        throw "${this} not supported";
    }
  }
}

class ByKeyFilter extends Filter {
  var key;

  ByKeyFilter(this.key) : super();

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }
    return record.key == key;
  }

  @override
  String toString() {
    return "${Field.key} = ${key}";
  }
}
