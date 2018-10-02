import 'package:sembast/sembast.dart';
import 'package:sembast/src/sort_order_impl.dart';

///
/// Helper to define one or multiple filters
///
class SembastFinder implements Finder {
  Filter filter;
  int offset;
  int limit;

  SembastFinder({this.filter, this.sortOrders, this.limit, this.offset});

  List<SortOrder> sortOrders = [];

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

  Finder clone({int limit}) {
    return Finder(
        filter: filter,
        sortOrders: sortOrders, //
        limit: limit == null ? this.limit : limit, //
        offset: offset);
  }

  @override
  String toString() {
    return "filter: ${filter}, sort: ${sortOrders}";
  }
}
