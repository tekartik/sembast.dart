library sembast;

//import 'package:tekartik_core/dev_utils.dart';
import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/database_mode.dart';
import 'package:sembast/src/filter.dart';
import 'package:sembast/src/finder.dart';
import 'package:sembast/src/sort_order.dart';

export 'package:sembast/src/database_mode.dart'
    show
        DatabaseMode,
        databaseModeCreate,
        databaseModeDefault,
        databaseModeEmpty,
        databaseModeExisting,
        databaseModeNeverFails;
export 'package:sembast/src/sort_order.dart';

export 'src/database.dart';
export 'src/record.dart';
export 'src/store.dart';

/// can return a future or not
typedef OnVersionChangedFunction(Database db, int oldVersion, int newVersion);

///
/// The database factory that allow opening database
///
abstract class DatabaseFactory {
  ///
  /// True if it has an associated storage (fs)
  ///
  bool get hasStorage;

  ///
  /// Open a new of existing database
  ///
  /// [path] is the location of the database
  /// [version] is the version expected, if not null and if the existing version is different, onVersionChanged is called
  /// [mode] is [DatabaseMode.DEFAULT] by default
  ///
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode});

  ///
  /// Delete a database if existing
  ///
  Future deleteDatabase(String path);
}

///
/// Exceptions
///
class DatabaseException implements Exception {
  static int errBadParam = 0;
  static int errDatabaseNotFound = 1;

  @deprecated
  static int BAD_PARAM = errBadParam;
  @deprecated
  static int DATABASE_NOT_FOUND = errDatabaseNotFound;

  final int _code;
  final String _message;

  int get code => _code;

  String get message => _message;

  DatabaseException.badParam(this._message) : _code = errBadParam;

  DatabaseException.databaseNotFound(this._message)
      : _code = errDatabaseNotFound;

  String toString() => "[${_code}] ${_message}";
}

//import 'package:tekartik_core/dev_utils.dart';

///
/// Database transaction
///
abstract class Transaction {
  @deprecated
  int get id;

  @deprecated
  bool get isCompleted;

  @deprecated
  Future get completed;
}

///
/// Filter for searching into the database
abstract class Filter {
  static bool matchRecord(Filter filter, Record record) {
    if (filter != null) {
      return filter.match(record);
    } else {
      return (!record.deleted);
    }
  }

  bool match(Record record) {
    if (record.deleted) {
      return false;
    }
    return true;
  }

  Filter();

  factory Filter.equal(String field, value) {
    return new FilterPredicate(field, FilterOperation.EQUAL, value);
  }

  factory Filter.notEqual(String field, value) {
    return new FilterPredicate(field, FilterOperation.NOT_EQUAL, value);
  }

  factory Filter.notNull(String field) {
    return new FilterPredicate(field, FilterOperation.NOT_EQUAL, null);
  }

  factory Filter.isNull(String field) {
    return new FilterPredicate(field, FilterOperation.EQUAL, null);
  }

  factory Filter.lessThan(String field, value) {
    return new FilterPredicate(field, FilterOperation.LESS_THAN, value);
  }

  factory Filter.lessThanOrEquals(String field, value) {
    return new FilterPredicate(
        field, FilterOperation.LESS_THAN_OR_EQUAL, value);
  }

  factory Filter.greaterThan(String field, value) {
    return new FilterPredicate(field, FilterOperation.GREATER_THAN, value);
  }

  factory Filter.greaterThanOrEquals(String field, value) {
    return new FilterPredicate(
        field, FilterOperation.GREATER_THAN_OR_EQUAL, value);
  }

  factory Filter.inList(String field, List value) {
    return new FilterPredicate(field, FilterOperation.IN, value);
  }

  factory Filter.or(List<Filter> filters) => new CompositeFilter.or(filters);

  factory Filter.and(List<Filter> filters) => new CompositeFilter.and(filters);

  factory Filter.byKey(key) => new ByKeyFilter(key);
}

///
/// Helper to define one or multiple filters
///
abstract class Finder {
  set filter(Filter filter);

  set offset(int offset);

  set limit(int limit);

  set sortOrders(List<SortOrder> sortOrders);

  set sortOrder(SortOrder sortOrder);

  factory Finder(
      {Filter filter, List<SortOrder> sortOrders, int limit, int offset}) {
    return new SembastFinder(
        filter: filter, sortOrders: sortOrders, limit: limit, offset: offset);
  }
}
