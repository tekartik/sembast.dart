import 'package:sembast/src/api/boundary.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/sort_order.dart';
import 'package:sembast/src/finder_impl.dart';

///
/// Finder helper for searching a given store
///
abstract class Finder {
  /// Set the filter.
  set filter(Filter filter);

  /// Set the offset.
  set offset(int offset);

  /// Set the limit.
  set limit(int limit);

  /// Set the sort orders.
  set sortOrders(List<SortOrder> sortOrders);

  /// Set the sort order.
  set sortOrder(SortOrder sortOrder);

  /// Set the start boundary.
  set start(Boundary start);

  /// Set the end boundary.
  set end(Boundary end);

  /// Specify a [filter].
  ///
  /// Having a [start] and/or [end] boundary requires a sortOrders when the values
  /// are specified. start/end is done after filtering.
  ///
  /// A finder without any info does not filter anything
  factory Finder(
      {Filter? filter,
      List<SortOrder>? sortOrders,
      int? limit,
      int? offset,
      Boundary? start,
      Boundary? end}) {
    return SembastFinder(
        filter: filter,
        sortOrders: sortOrders,
        limit: limit,
        offset: offset,
        start: start,
        end: end);
  }
}
