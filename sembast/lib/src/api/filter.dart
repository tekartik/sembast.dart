import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/record.dart';

///
/// Filter for searching into the database
abstract class Filter {
  static bool matchRecord(Filter filter, Record record) {
    if (filter != null) {
      return filter.match(record);
    } else {
      return (!record.deleted);
    }
  }

  bool match(Record record) {
    if (record.deleted) {
      return false;
    }
    return true;
  }

  Filter();

  // 2018-11-29 will be deprecated in 2.0
  factory Filter.equal(String field, value) => Filter.equals(field, value);

  /// [field] must be equals to [value]
  factory Filter.equals(String field, value) {
    return FilterPredicate(field, FilterOperation.equals, value);
  }

  // 2018-11-29 will be deprecated in 2.0
  factory Filter.notEqual(String field, value) =>
      Filter.notEquals(field, value);

  factory Filter.notEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.notEquals, value);
  }

  factory Filter.notNull(String field) {
    return FilterPredicate(field, FilterOperation.notEquals, null);
  }

  factory Filter.isNull(String field) {
    return FilterPredicate(field, FilterOperation.equals, null);
  }

  factory Filter.lessThan(String field, value) {
    return FilterPredicate(field, FilterOperation.lessThan, value);
  }

  factory Filter.lessThanOrEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.lessThanOrEquals, value);
  }

  factory Filter.greaterThan(String field, value) {
    return FilterPredicate(field, FilterOperation.greaterThan, value);
  }

  factory Filter.greaterThanOrEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.greaterThanOrEquals, value);
  }

  factory Filter.inList(String field, List value) {
    return FilterPredicate(field, FilterOperation.inList, value);
  }

  /// Use RegExp pattern matching for the given field which has to be a string
  factory Filter.matches(String field, String pattern) =>
      Filter.matchesRegExp(field, RegExp(pattern));

  factory Filter.matchesRegExp(String field, RegExp regExp) {
    return FilterPredicate(field, FilterOperation.matches, regExp);
  }

  factory Filter.or(List<Filter> filters) => CompositeFilter.or(filters);

  factory Filter.and(List<Filter> filters) => CompositeFilter.and(filters);

  factory Filter.byKey(key) => ByKeyFilter(key);
}
