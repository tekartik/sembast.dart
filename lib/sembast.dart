library sembast;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/database_mode.dart';
import 'package:sembast/src/filter.dart';
import 'package:sembast/src/finder.dart';
import 'package:sembast/src/sembast_code_impl.dart';
import 'package:sembast/src/sort_order.dart';

export 'package:sembast/src/boundary.dart';
export 'package:sembast/src/database_mode.dart'
    show
        DatabaseMode,
        // ignore: deprecated_member_use
        databaseModeCreate,
        // ignore: deprecated_member_use
        databaseModeDefault,
        // ignore: deprecated_member_use
        databaseModeEmpty,
        // ignore: deprecated_member_use
        databaseModeExisting,
        // ignore: deprecated_member_use
        databaseModeNeverFails;
export 'package:sembast/src/sort_order.dart';

export 'src/database.dart';
export 'src/record.dart';
export 'src/store.dart';

//import 'package:tekartik_core/dev_utils.dart';
// ignore: deprecated_member_use
// ignore: deprecated_member_use
// ignore: deprecated_member_use
// ignore: deprecated_member_use
// ignore: deprecated_member_use
// ignore: deprecated_member_use

/// can return a future or not
typedef OnVersionChangedFunction = FutureOr Function(
    Database db, int oldVersion, int newVersion);

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
  /// A custom [code] can be used to load/save a record, allowing for user encryption
  ///
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode,
      SembastCodec codec});

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
  static int errInvalidCodec = 2;

  final int _code;
  final String _message;

  int get code => _code;

  String get message => _message;

  DatabaseException.badParam(this._message) : _code = errBadParam;

  DatabaseException.databaseNotFound(this._message)
      : _code = errDatabaseNotFound;

  DatabaseException.invalidCodec(this._message) : _code = errInvalidCodec;
  @override
  String toString() => "[${_code}] ${_message}";
}

//import 'package:tekartik_core/dev_utils.dart';

abstract class StoreTransaction extends StoreExecutor {}

///
/// Database transaction
///
abstract class Transaction implements StoreTransaction, TransactionExecutor {}

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

  // 2018-11-29 will be deprecated in 2.0
  factory Filter.equal(String field, value) => Filter.equals(field, value);

  /// [field] must be equals to [value]
  factory Filter.equals(String field, value) {
    return FilterPredicate(field, FilterOperation.equals, value);
  }

  // 2018-11-29 will be deprecated in 2.0
  factory Filter.notEqual(String field, value) =>
      Filter.notEquals(field, value);

  factory Filter.notEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.notEquals, value);
  }

  factory Filter.notNull(String field) {
    return FilterPredicate(field, FilterOperation.notEquals, null);
  }

  factory Filter.isNull(String field) {
    return FilterPredicate(field, FilterOperation.equals, null);
  }

  factory Filter.lessThan(String field, value) {
    return FilterPredicate(field, FilterOperation.lessThan, value);
  }

  factory Filter.lessThanOrEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.lessThanOrEquals, value);
  }

  factory Filter.greaterThan(String field, value) {
    return FilterPredicate(field, FilterOperation.greaterThan, value);
  }

  factory Filter.greaterThanOrEquals(String field, value) {
    return FilterPredicate(field, FilterOperation.greaterThanOrEquals, value);
  }

  factory Filter.inList(String field, List value) {
    return FilterPredicate(field, FilterOperation.inList, value);
  }

  /// Use RegExp pattern matching for the given field which has to be a string
  factory Filter.matches(String field, String pattern) =>
      Filter.matchesRegExp(field, RegExp(pattern));

  factory Filter.matchesRegExp(String field, RegExp regExp) {
    return FilterPredicate(field, FilterOperation.matches, regExp);
  }

  factory Filter.or(List<Filter> filters) => CompositeFilter.or(filters);

  factory Filter.and(List<Filter> filters) => CompositeFilter.and(filters);

  factory Filter.byKey(key) => ByKeyFilter(key);
}

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
  /// are specified. start/end is done after filtering
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

/// The codec to use to read/write records
abstract class SembastCodec {
  /// The public signature, can be a constant, a password hash...
  String get signature;

  Codec<Map<String, dynamic>, String> get codec;

  factory SembastCodec(
          {@required String signature,
          @required Codec<Map<String, dynamic>, String> codec}) =>
      SembastCodecImpl(signature: signature, codec: codec);
}
