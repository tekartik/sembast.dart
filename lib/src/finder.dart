import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';
import 'package:sembast/src/sort_order_impl.dart';
import 'package:sembast/src/utils.dart';

///
/// Helper to define one or multiple filters
///
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
    int result = 0;
    if (sortOrders != null) {
      for (SortOrder order in sortOrders) {
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
    int result = compare(record1, record2);
    if (result == 0) {
      return compareKey(record1.key, record2.key);
    }
    return result;
  }

  // used in search, record is the record checked from the db
  int compareToBoundary(Record record, Boundary boundary) {
    int result = 0;
    if (sortOrders != null) {
      for (int i = 0; i < sortOrders.length; i++) {
        SortOrder order = sortOrders[i];
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
      SembastBoundary sembastBoundary = boundary;
      if (sembastBoundary.record?.key != null) {
        // Compare key
        return compareKey(record.key, sembastBoundary.record.key);
      }
    }

    return result;
  }

  bool starts(Record record, Boundary boundary) {
    int result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return true;
    }
    return result > 0;
  }

  bool ends(Record record, Boundary boundary) {
    int result = compareToBoundary(record, boundary);
    if (result == 0 && boundary.include) {
      return false;
    }
    return result >= 0;
  }

  Finder clone({int limit}) {
    return Finder(
        filter: filter,
        sortOrders: sortOrders, //
        limit: limit == null ? this.limit : limit, //
        offset: offset,
        start: start,
        end: end);
  }

  @override
  String toString() {
    return "filter: ${filter}, sort: ${sortOrders}";
  }

  List<Record> filterStart(List<Record> results) {
    int startIndex = 0;
    for (int i = 0; i < results.length; i++) {
      if (starts(results[i], start)) {
        startIndex = i;
        break;
      }
    }
    if (startIndex != 0) {
      return results.sublist(startIndex);
    }
    return results;
  }

  List<Record> filterEnd(List<Record> results) {
    int endIndex = 0;
    for (int i = results.length - 1; i >= 0; i--) {
      if (ends(results[i], end)) {
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
}
