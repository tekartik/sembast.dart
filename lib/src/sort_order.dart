import 'package:sembast/src/sembast_sort_order.dart';

///
/// Sort order
///
class SortOrder {
  ///
  /// default is [ascending] = true
  ///
  /// user withParam
  factory SortOrder(String field, [bool ascending, bool nullLast]) {
    return new SembastSortOrder(field, ascending, nullLast);
  }
}
