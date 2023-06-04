import 'package:sembast/src/sort_order_impl.dart';

///
/// Sort order
///
class SortOrder<T extends Object?> {
  /// Sort order on given field; by default [ascending] is true, [nullLast] is
  /// false.
  ///
  /// When [ascending] nulls are position first, When not [ascending] nulls
  /// are positioned last
  ///
  /// [nullLast] means nulls are sorted last in ascending order
  /// so if not [ascending], it means null are sorted first
  factory SortOrder(String field,
      [bool ascending = true, bool nullLast = false]) {
    return SembastSortOrder<T>(field, ascending, nullLast);
  }

  /// Sort order on given field; by default [ascending] is true, [nullLast] is
  /// false.
  ///
  /// When [ascending] nulls are position first, When not [ascending] nulls
  /// are positioned last
  ///
  /// [nullLast] means nulls are sorted last in ascending order
  /// so if not [ascending], it means null are sorted first
  factory SortOrder.custom(
      String field, int Function(T value1, T value2) compare,
      [bool ascending = true, bool nullLast = false]) {
    return SembastCustomSortOrder<T>(field, compare, ascending, nullLast);
  }
}
