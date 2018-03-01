library sembast;

//import 'package:tekartik_core/dev_utils.dart';
import 'package:logging/logging.dart';
import 'dart:async';
import 'dart:convert';
import 'package:synchronized/synchronized.dart';

part 'src/sembast_database.dart';
part 'src/sembast_store.dart';
part 'src/sembast_record.dart';
part 'src/sembast_sort_order.dart';

/// can return a future or not
typedef OnVersionChangedFunction(Database db, int oldVersion, int newVersion);

///
/// The modes in which a Database can be opened.
///
class DatabaseMode {
  /// The default mode
  /// The database is created if not found
  /// This is the default
  static const CREATE = const DatabaseMode._internal(0);

  /// The mode for opening an existing database
  static const EXISTING = const DatabaseMode._internal(1);

  /// The mode for emptying the existing content if any
  static const EMPTY = const DatabaseMode._internal(2);

  /// This mode will never fails
  /// Corrupted database will be deleted
  static const NEVER_FAILS = const DatabaseMode._internal(3);

  final int _mode;

  int get mode => _mode;

  const DatabaseMode._internal(this._mode);
}

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
  /// [mode] is [DatabaseMode.CREATE] by default
  ///
  Future<Database> openDatabase(String path,
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode});

  ///
  /// Delete a database if existing
  ///
  Future deleteDatabase(String path);

  //Stream<String> getData(String path);
}

///
/// Storage implementation
///
/// where the database is read/written to if needed
///
abstract class DatabaseStorage {
  String get path;
  bool get supported;
  DatabaseStorage();

  DatabaseStorage get tmpStorage;
  Future tmpRecover();
  Future delete();
  Future<bool> find();
  Future findOrCreate();

  Stream<String> readLines();
  Future appendLines(List<String> lines);
  Future appendLine(String line) => appendLines([line]);
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

const String _db_version = "version";
const String _db_sembast_version = "sembast";
const String _record_key = "key";
const String _store_name = "store";
const String _record_value =
    "value"; // only for simple type where the key is not a string
const String _record_deleted = "deleted"; // boolean

const String _main_store = "_main"; // main store name;

class _Meta {
  int version;
  int sembastVersion = 1;

  _Meta.fromMap(Map map) {
    version = map[_db_version] as int;
    sembastVersion = map[_db_sembast_version] as int;
  }

  static bool isMapMeta(Map map) {
    return map[_db_version] != null;
  }

  _Meta(this.version);

  Map toMap() {
    var map = {_db_version: version, _db_sembast_version: sembastVersion};
    return map;
  }

  @override
  String toString() {
    return toMap().toString();
  }
}

///
/// Database transaction
///
class Transaction {
  final int id;

  // make the completer async as the Transaction following
  // action is not a priority
  Completer _completer = new Completer();
  Transaction._(this.id);

  bool get isCompleted => _completer.isCompleted;
  Future get completed => _completer.future;

  @override
  String toString() {
    return "txn ${id}${_completer.isCompleted ? ' completed' : ''}";
  }
}

class _CompositeFilter extends Filter {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  _CompositeFilter.or(this.filters)
      : isAnd = false,
        super._();
  _CompositeFilter.and(this.filters)
      : isAnd = true,
        super._();

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }

    for (Filter filter in filters) {
      if (filter.match(record)) {
        if (isOr) {
          return true;
        }
      } else {
        if (isAnd) {
          return false;
        }
      }
    }
    // if isOr, nothing has matches so far
    return isAnd;
  }

  @override
  String toString() {
    return filters.join(' ${isAnd ? "AND" : "OR" } ');
  }
}

class _FilterOperation {
  final int value;
  const _FilterOperation._(this.value);
  static const _FilterOperation EQUAL = const _FilterOperation._(1);
  static const _FilterOperation NOT_EQUAL = const _FilterOperation._(2);
  static const _FilterOperation LESS_THAN = const _FilterOperation._(3);
  static const _FilterOperation LESS_THAN_OR_EQUAL =
      const _FilterOperation._(4);
  static const _FilterOperation GREATER_THAN = const _FilterOperation._(5);
  static const _FilterOperation GREATER_THAN_OR_EQUAL =
      const _FilterOperation._(6);
  static const _FilterOperation IN = const _FilterOperation._(7);
  @override
  String toString() {
    switch (this) {
      case _FilterOperation.EQUAL:
        return "=";
      case _FilterOperation.NOT_EQUAL:
        return "!=";
      case _FilterOperation.LESS_THAN:
        return "<";
      case _FilterOperation.LESS_THAN_OR_EQUAL:
        return "<=";
      case _FilterOperation.GREATER_THAN:
        return ">";
      case _FilterOperation.GREATER_THAN_OR_EQUAL:
        return ">=";
      case _FilterOperation.IN:
        return "IN";
      default:
        throw "${this} not supported";
    }
  }
}

class _ByKeyFilter extends Filter {
  var key;

  _ByKeyFilter(this.key) : super._();
  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }
    return record.key == key;
  }

  @override
  String toString() {
    return "${Field.key} = ${key}";
  }
}

class _FilterPredicate extends Filter {
  String field;
  _FilterOperation operation;
  var value;
  _FilterPredicate(this.field, this.operation, this.value) : super._();

  @override
  bool match(Record record) {
    if (!super.match(record)) {
      return false;
    }

    int _safeCompare(dynamic value1, dynamic value2) {
      try {
        if (value1 is Comparable && value2 is Comparable) {
          return Comparable.compare(value1, value2);
        }
      } catch (_) {}
      return 0;
    }

    switch (operation) {
      case _FilterOperation.EQUAL:
        return record[field] == value;
      case _FilterOperation.NOT_EQUAL:
        return record[field] != value;
      case _FilterOperation.LESS_THAN:
        return _safeCompare(record[field], value) < 0;
      case _FilterOperation.LESS_THAN_OR_EQUAL:
        return _safeCompare(record[field], value) <= 0;
      case _FilterOperation.GREATER_THAN:
        return _safeCompare(record[field], value) > 0;
      case _FilterOperation.GREATER_THAN_OR_EQUAL:
        return _safeCompare(record[field], value) >= 0;
      case _FilterOperation.IN:
        return (value as List).contains(record[field]);
      default:
        throw "${this} not supported";
    }
  }

  @override
  String toString() {
    return "${field} ${operation} ${value}";
  }
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

  Filter._();
  factory Filter.equal(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.EQUAL, value);
  }
  factory Filter.notEqual(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.NOT_EQUAL, value);
  }
  factory Filter.notNull(String field) {
    return new _FilterPredicate(field, _FilterOperation.NOT_EQUAL, null);
  }
  factory Filter.isNull(String field) {
    return new _FilterPredicate(field, _FilterOperation.EQUAL, null);
  }
  factory Filter.lessThan(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.LESS_THAN, value);
  }
  factory Filter.lessThanOrEquals(String field, value) {
    return new _FilterPredicate(
        field, _FilterOperation.LESS_THAN_OR_EQUAL, value);
  }
  factory Filter.greaterThan(String field, value) {
    return new _FilterPredicate(field, _FilterOperation.GREATER_THAN, value);
  }
  factory Filter.greaterThanOrEquals(String field, value) {
    return new _FilterPredicate(
        field, _FilterOperation.GREATER_THAN_OR_EQUAL, value);
  }
  factory Filter.inList(String field, List value) {
    return new _FilterPredicate(field, _FilterOperation.IN, value);
  }

  factory Filter.or(List<Filter> filters) => new _CompositeFilter.or(filters);
  factory Filter.and(List<Filter> filters) => new _CompositeFilter.and(filters);
  factory Filter.byKey(key) => new _ByKeyFilter(key);
}

///
/// Helper to define one or multiple filters
///
class Finder {
  Filter filter;
  int offset;
  int limit;

  Finder({this.filter, this.sortOrders, this.limit, this.offset});
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
        result = order.compare(record1, record2);
        // stop as soon as they differ
        if (result != 0) {
          break;
        }
      }
    }

    return result;
  }

  Finder clone({int limit}) {
    return new Finder(
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
