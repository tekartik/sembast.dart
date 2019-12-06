import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/boundary.dart';
import 'package:sembast/src/api/compat/record.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/sort_order.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';
import 'package:sembast/src/utils.dart';

// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: public_member_api_docs
/// @deprecated v2
///
/// Helper to define one or multiple filters
///
@deprecated
class SembastFinder implements Finder {
  Filter filter;
  int offset;
  int limit;

  SembastFinder(
      {this.filter,
      this.sortOrders,
      this.limit,
      this.offset,
      this.start,
      this.end});

  Boundary start;
  Boundary end;
  List<SortOrder> sortOrders = [];

  @override
  set sortOrder(SortOrder sortOrder) {
    sortOrders = [sortOrder];
  }

//  bool match(Record record) {
//    if (record.deleted) {
//      return false;
//    }
//    if (filter != null) {
//      return filter.match(record);
//    }
//    return true;
//  }
  int compare(Record record1, Record record2) {
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

  int compareThenKey(Record record1, Record record2) {
    final result = compare(record1, record2);
    if (result == 0) {
      return compareKey(record1.key, record2.key);
    }
    return result;
  }

  // used in search, record is the record checked from the db
  int compareToBoundary(Record record, Boundary boundary) {
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

  bool starts(Record record, Boundary boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return true;
    }
    return result > 0;
  }

  bool ends(Record record, Boundary boundary) {
    final result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return false;
    }
    return result >= 0;
  }

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
    return 'filter: ${filter}, sort: ${sortOrders}';
  }
}
