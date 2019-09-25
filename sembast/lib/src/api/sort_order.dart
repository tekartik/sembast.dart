import 'package:sembast/src/sort_order_impl.dart';

///
/// Sort order
///
class SortOrder {
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
    return SembastSortOrder(field, ascending, nullLast);
  }
}
