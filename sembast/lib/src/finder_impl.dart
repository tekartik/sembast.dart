import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/cooperator.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/sort.dart';
import 'package:sembast/src/sort_order_impl.dart';
import 'package:sembast/src/utils.dart';

/// Sort and limit a list.
Future<List<ImmutableSembastRecord>> sortAndLimit(
    List<ImmutableSembastRecord> results,
    SembastFinder finder,
    Cooperator cooperator) async {
  final cooperateOn = cooperator?.cooperateOn == true;
  if (finder != null) {
    // sort
    if (cooperateOn) {
      var sort = Sort(cooperator);
      await sort.sort(
          results,
          (SembastRecord record1, SembastRecord record2) =>
              finder.compareThenKey(record1, record2));
    } else {
      results
          .sort((record1, record2) => finder.compareThenKey(record1, record2));
    }

    Future<List<ImmutableSembastRecord>> filterStart(
        List<ImmutableSembastRecord> results) async {
      var startIndex = 0;
      for (var i = 0; i < results.length; i++) {
        if (cooperator?.needCooperate == true) {
          await cooperator.cooperate();
        }
        if (finder.starts(results[i], finder.start)) {
          startIndex = i;
          break;
        }
      }
      if (startIndex != 0) {
        return results.sublist(startIndex);
      }
      return results;
    }

    Future<List<ImmutableSembastRecord>> filterEnd(
        List<ImmutableSembastRecord> results) async {
      var endIndex = 0;
      for (var i = results.length - 1; i >= 0; i--) {
        if (cooperator?.needCooperate == true) {
          await cooperator.cooperate();
        }
        if (finder.ends(results[i], finder.end)) {
          // continue
        } else {
          endIndex = i + 1;
          break;
        }
      }
      if (endIndex != results.length) {
        return results.sublist(0, endIndex);
      }
      return results;
    }

    try {
      // handle start
      if (finder.start != null) {
        results = await filterStart(results);
      }
      // handle end
      if (finder.end != null) {
        results = await filterEnd(results);
      }
    } catch (e) {
      print('Make sure you are comparing boundaries with a proper type');
      rethrow;
    }

    // offset
    if (finder.offset != null) {
      results = results.sublist(min(finder.offset, results.length));
    }
    // limit
    if (finder.limit != null) {
      results = results.sublist(0, min(finder.limit, results.length));
    }
  } else {
    if (cooperateOn) {
      var sort = Sort(cooperator);
      await sort.sort(results, compareRecordKey);
    } else {
      results.sort(compareRecordKey);
    }
  }
  return results;
}

/// Finder implementation.
class SembastFinder implements Finder {
  /// Filter.
  Filter filter;

  /// Offset.
  int offset;

  /// Limit.
  int limit;

  /// Builder.
  SembastFinder(
      {this.filter,
      this.sortOrders,
      this.limit,
      this.offset,
      this.start,
      this.end});

  /// Start boundary.
  Boundary start;

  /// End boundary.
  Boundary end;

  /// Sort orders
  List<SortOrder> sortOrders = [];

  @override
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }

  /// Compare 2 records.
  int compare(SembastRecord record1, SembastRecord record2) {
    var result = 0;
    if (sortOrders != null) {
      for (var order in sortOrders) {
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
  int compareToBoundary(SembastRecord record, Boundary boundary) {
    var result = 0;
    if (sortOrders != null) {
      for (var i = 0; i < sortOrders.length; i++) {
        final order = sortOrders[i];
        result =
            (order as SembastSortOrder).compareToBoundary(record, boundary, i);
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
        return compareKey(record.key, sembastBoundary.snapshot.key);
      }
    }

    return result;
  }

  /// True if we are at start  boundary.
  bool starts(SembastRecord record, Boundary boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return true;
    }
    return result > 0;
  }

  /// True if we are at end boundary.
  bool ends(SembastRecord record, Boundary boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return false;
    }
    return result >= 0;
  }

  /// Clone a filter with a given limit.
  Finder clone({int limit}) {
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
