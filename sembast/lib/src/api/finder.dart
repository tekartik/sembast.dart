import 'package:sembast/src/api/boundary.dart';
import 'package:sembast/src/api/compat/finder.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/sort_order.dart';

///
/// Finder helper for searching a given store
///
abstract class Finder {
  set filter(Filter filter);

  set offset(int offset);

  set limit(int limit);

  set sortOrders(List<SortOrder> sortOrders);

  set sortOrder(SortOrder sortOrder);

  set start(Boundary start);

  set end(Boundary end);

  /// Specify a [filter].
  ///
  /// Having a [start] and/or [end] boundary requires a sortOrders when the values
  /// are specified. start/end is done after filtering.
  ///
  /// A finder without any info does not filter anything
  factory Finder(
      {Filter filter,
      List<SortOrder> sortOrders,
      int limit,
      int offset,
      Boundary start,
      Boundary end}) {
    return SembastFinder(
        filter: filter,
        sortOrders: sortOrders,
        limit: limit,
        offset: offset,
        start: start,
        end: end);
  }
}
