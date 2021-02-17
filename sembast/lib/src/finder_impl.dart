import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/filter_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/utils.dart';

/// Check filter and start/end boundaries, not the deleted flags
bool finderMatchesFilterAndBoundaries(
    SembastFinder? finder, RecordSnapshot record) {
  if (finder == null) {
    return true;
  }
  if (!finderRecordMatchBoundaries(finder, record)) {
    return false;
  }
  if (!filterMatchesRecord(finder.filter, record)) {
    return false;
  }
  return true;
}

/// Limit a sorted list
List<ImmutableSembastRecord>? recordsLimit(
    List<ImmutableSembastRecord>? results, SembastFinder? finder) {
  if (finder != null) {
    // offset
    if (finder.offset != null) {
      results = results!.sublist(min(finder.offset!, results.length));
    }
    // limit
    if (finder.limit != null) {
      results = results!.sublist(0, min(finder.limit!, results.length));
    }
  }
  return results;
}

/// Finder implementation.
class SembastFinder implements Finder {
  /// Filter.
  Filter? filter;

  /// Offset.
  int? offset;

  /// Limit.
  int? limit;

  /// Builder.
  SembastFinder(
      {this.filter,
      this.sortOrders,
      this.limit,
      this.offset,
      this.start,
      this.end});

  /// Start boundary.
  Boundary? start;

  /// End boundary.
  Boundary? end;

  /// Sort orders
  List<SortOrder>? sortOrders = [];

  @override
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }

  /// Compare 2 records.
  int compare(SembastRecord record1, SembastRecord record2) {
    var result = 0;
    if (sortOrders != null) {
      for (var order in sortOrders!) {
        result = (order as SembastSortOrder).compare(record1, record2);
        // stop as soon as they differ
        if (result != 0) {
          break;
        }
      }
    }
    return result;
  }

  /// Compare records then then key
  int compareThenKey(SembastRecord record1, SembastRecord record2) {
    final result = compare(record1, record2);
    if (result == 0) {
      return compareKey(record1.key, record2.key);
    }
    return result;
  }

  /// Compare to boundary.
  ///
  /// Used in search, record is the record checked from the db
  int compareToBoundary(RecordSnapshot record, Boundary? boundary) {
    var result = 0;
    if (sortOrders != null) {
      for (var i = 0; i < sortOrders!.length; i++) {
        final order = sortOrders![i];
        result =
            (order as SembastSortOrder).compareToBoundary(record, boundary!, i);
        // stop as soon as they differ
        if (result != 0) {
          break;
        }
      }
    }
    if (result == 0) {
      // Sort by key
      final sembastBoundary = boundary as SembastBoundary;
      if (sembastBoundary.snapshot?.key != null) {
        // Compare key
        return compareKey(record.key, sembastBoundary.snapshot!.key);
      }
    }

    return result;
  }

  /// True if we match the start boundary.
  bool starts(RecordSnapshot record, Boundary? boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary!.include) {
      return true;
    }
    return result > 0;
  }

  /// True if we don't match boundaries.
  bool ends(RecordSnapshot record, Boundary? boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary!.include) {
      return true;
    }
    return result < 0;
  }

  /// Clone a filter with a given limit.
  Finder clone({int? limit}) {
    return Finder(
        filter: filter,
        sortOrders: sortOrders,
        //
        limit: limit ?? this.limit,
        //
        offset: offset,
        start: start,
        end: end);
  }

  /// Clone a filter without Limits (and offset).
  Finder cloneWithoutLimits() {
    return Finder(
        filter: filter, sortOrders: sortOrders, start: start, end: end);
  }

  @override
  String toString() {
    return 'Finder(${{
      if (filter != null) 'filter': filter,
      if (sortOrders != null) 'sort': sortOrders,
      if (offset != null) 'offset': offset,
      if (limit != null) 'limit': limit,
      if (start != null) 'start': start,
      if (end != null) 'limit': end,
    }})';
  }
}

/// Clone a filter to the first item found (i.e. set limit to 1).
SembastFinder cloneFinderFindFirst(Finder finder) {
  if (finder != null) {
    if ((finder as SembastFinder).limit != 1) {
      finder = (finder as SembastFinder).clone(limit: 1);
    }
  } else {
    finder = SembastFinder(limit: 1);
  }
  return finder as SembastFinder;
}
