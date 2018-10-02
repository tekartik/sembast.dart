import 'package:sembast/src/sort_order_impl.dart';

///
/// Sort order
///
class SortOrder {
  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  factory SortOrder(String field, [bool ascending, bool nullLast]) {
    return SembastSortOrder(field, ascending, nullLast);
  }
}
