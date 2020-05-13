import 'package:sembast/sembast.dart';
import 'package:sembast/src/filter_impl.dart';

///
/// Filter for searching into the database
///
/// Don't subclass
abstract class Filter {
  /// [field] value must be equals to [value].
  factory Filter.equals(String field, value, {bool anyInList}) {
    return SembastEqualsFilter(field, value, anyInList);
  }

  /// Filter where the [field] value is not equals to the specified value.
  factory Filter.notEquals(String field, value) {
    return SembastFilterPredicate(field, FilterOperation.notEquals, value);
  }

  /// Filter where the [field] value is not null.
  factory Filter.notNull(String field) => Filter.notEquals(field, null);

  /// Filter where the [field] value is null.
  factory Filter.isNull(String field) => Filter.equals(field, null);

  /// Filter where the [field] value is less than the specified [value].
  factory Filter.lessThan(String field, value) {
    return SembastFilterPredicate(field, FilterOperation.lessThan, value);
  }

  /// Filter where the [field] value is less than or equals to the
  /// specified [value].
  factory Filter.lessThanOrEquals(String field, value) {
    return SembastFilterPredicate(
        field, FilterOperation.lessThanOrEquals, value);
  }

  /// Filter where the [field] is greater than the specified [value]
  factory Filter.greaterThan(String field, value) {
    return SembastFilterPredicate(field, FilterOperation.greaterThan, value);
  }

  /// Filter where the [field] is less than or equals to the specified [value]
  factory Filter.greaterThanOrEquals(String field, value) {
    return SembastFilterPredicate(
        field, FilterOperation.greaterThanOrEquals, value);
  }

  /// Filter where the [field] is in the [list] of values
  factory Filter.inList(String field, List list) {
    return SembastFilterPredicate(field, FilterOperation.inList, list);
  }

  /// Use RegExp pattern matching for the given [field] which has to be a string.
  ///
  /// If [anyInList] is true, it means that if field is a list, a record matches
  /// if any of the list item matches the pattern.
  factory Filter.matches(String field, String pattern, {bool anyInList}) =>
      Filter.matchesRegExp(field, RegExp(pattern), anyInList: anyInList);

  /// Filter [field] value using [regExp] regular expression.
  ///
  /// If [anyInList] is true, it means that if field is a list, a record matches
  /// if any of the list item matches the pattern.
  factory Filter.matchesRegExp(String field, RegExp regExp, {bool anyInList}) {
    return SembastMatchesFilter(field, regExp, anyInList);
  }

  /// Record must match any of the given [filters].
  ///
  /// If you only have two filters, you can also write `filter1 | filter2`.
  factory Filter.or(List<Filter> filters) => SembastCompositeFilter.or(filters);

  /// Record must match all of the given [filters].
  ///
  /// If you only have two filters, you can also write `filter1 & filter2`.
  factory Filter.and(List<Filter> filters) =>
      SembastCompositeFilter.and(filters);

  /// Filter by [key].
  ///
  /// Less efficient than using `store.record(key)`.
  factory Filter.byKey(key) => Filter.equals(Field.key, key);

  /// Custom filter, use with caution and do not modify record data as it
  /// provides a raw access to the record internal value for efficiency.
  factory Filter.custom(bool Function(RecordSnapshot record) matches) =>
      SembastCustomFilter(matches);
}

/// Provides convenience methods for combining multiple [Filter]s.
extension SembastFilterCombination on Filter {
  /// Record must match this or [other] filter.
  ///
  /// Use [Filter.or] to combine more than two filters.
  Filter operator |(Filter other) => SembastCompositeFilter.or([this, other]);

  /// Record must match this and [other] filter.
  ///
  /// Use [Filter.and] to combine more than two filters.
  Filter operator &(Filter other) => SembastCompositeFilter.and([this, other]);
}
