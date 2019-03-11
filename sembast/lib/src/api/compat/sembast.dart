import 'package:sembast/src/api/compat/record.dart';
import 'package:sembast/src/api/compat/store.dart';
import 'package:sembast/src/api/filter.dart';
import 'package:sembast/src/api/finder.dart';
import 'package:sembast/src/api/sembast.dart';

export 'package:sembast/src/api/compat/database_mode.dart';
export 'package:sembast/src/api/compat/finder.dart';
export 'package:sembast/src/api/compat/record.dart';
export 'package:sembast/src/api/compat/store.dart';

abstract class TransactionExecutor extends DatabaseExecutor {
  /// The main store used
  StoreExecutor get mainStore;

  /// All the stores in the database
  Iterable<StoreExecutor> get stores;

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  StoreExecutor getStore(String storeName);

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  ///
  /// find existing store
  ///
  StoreExecutor findStore(String storeName);
}

abstract class DatabaseExecutor extends StoreExecutor {
  ///
  /// Put a record
  ///
  Future<Record> putRecord(Record record);

  ///
  /// Put a list or records
  ///
  Future<List<Record>> putRecords(List<Record> records);

  ///
  /// delete a [record]
  ///
  Future deleteRecord(Record record);
}

abstract class StoreExecutor extends BaseExecutor {
  ///
  /// delete all records in a store
  ///
  Future clear();

  ///
  /// get a record by key
  ///
  Future<Record> getRecord(dynamic key);

  ///
  /// Get all records from a list of keys
  ///
  Future<List<Record>> getRecords(Iterable keys);

  ///
  /// return the list of deleted keys
  ///
  Future deleteAll(Iterable keys);

  ///
  /// stream all the records
  ///
  Stream<Record> get records;
}

///
/// Method shared by Store and Database (main store)
abstract class BaseExecutor {
  Store get store;

  ///
  /// get a value from a key
  /// null if not found or if value null
  ///
  Future get(dynamic key);

  ///
  /// count all records
  ///
  Future<int> count([Filter filter]);

  ///
  /// put a value with an optional key. Returns the key
  ///
  Future put(dynamic value, [dynamic key]);

  ///
  /// Update an existing record if any with the given key
  /// if value is a map, existing fields are replaced but not removed unless
  /// specified ([FieldValue.delete])
  ///
  /// Does not do anything if the record does not exist
  ///
  /// Returns the record value (merged) or null if the record was not found
  ///
  Future update(dynamic value, dynamic key);

  ///
  /// delete a record by key
  ///
  Future delete(dynamic key);

  ///
  /// find the first matching record
  ///
  Future<Record> findRecord(Finder finder);

  ///
  /// find all records
  ///
  Future<List<Record>> findRecords(Finder finder);

  /// new in 1.7.1
  Future<bool> containsKey(dynamic key);

  /// new in 1.9.0
  Future<List> findKeys(Finder finder);

  /// new in 1.9.0
  Future findKey(Finder finder);
}

//import 'package:tekartik_core/dev_utils.dart';

abstract class StoreTransaction extends StoreExecutor {}

class CompositeFilter extends Filter {
  bool isAnd; // if false it is OR
  bool get isOr => !isAnd;
  List<Filter> filters;

  CompositeFilter.or(this.filters) : isAnd = false;

  CompositeFilter.and(this.filters) : isAnd = true;

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
    return filters.join(' ${isAnd ? "AND" : "OR"} ');
  }
}

class FilterPredicate extends Filter {
  String field;
  FilterOperation operation;
  var value;

  FilterPredicate(this.field, this.operation, this.value) : super();

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
      return null;
    }

    bool _lessThan(dynamic value1, dynamic value2) {
      var cmp = _safeCompare(value1, value2);
      return cmp != null && cmp < 0;
    }

    bool _greaterThan(dynamic value1, dynamic value2) {
      var cmp = _safeCompare(value1, value2);
      return cmp != null && cmp > 0;
    }

    bool _matches(dynamic value1, dynamic value2) {
      final fieldValue = value1 as String;
      final regExp = value2 as RegExp;
      // a null value is never ok (use isNotNulllboth null is ok
      if (fieldValue == null) {
        return false;
      }
      return regExp.hasMatch(fieldValue);
    }

    // empty record or not map? refuse
    if ((!(record.value is Map)) &&
        (field != Field.value && field != Field.key)) {
      return false;
    }

    var fieldValue = record[field];
    switch (operation) {
      case FilterOperation.equals:
        return fieldValue == value;
      case FilterOperation.notEquals:
        return fieldValue != value;
      case FilterOperation.lessThan:
        // return _safeCompare(record[field], value) < 0;
        return _lessThan(fieldValue, value);
      case FilterOperation.lessThanOrEquals:
        return _lessThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) <= 0;
      case FilterOperation.greaterThan:
        return _greaterThan(fieldValue, value);
      // return _safeCompare(record[field], value) > 0;
      case FilterOperation.greaterThanOrEquals:
        return _greaterThan(fieldValue, value) || fieldValue == value;
      // return _safeCompare(record[field], value) >= 0;
      case FilterOperation.inList:
        return (value as List).contains(record[field]);
      case FilterOperation.matches:
        return _matches(fieldValue, value);

      default:
        throw "${this} not supported";
    }
  }

  @override
  String toString() {
    return "${field} ${operation} ${value}";
  }
}

class FilterOperation {
  final int value;

  const FilterOperation._(this.value);

  static const FilterOperation equals = FilterOperation._(1);
  static const FilterOperation notEquals = FilterOperation._(2);
  static const FilterOperation lessThan = FilterOperation._(3);
  static const FilterOperation lessThanOrEquals = FilterOperation._(4);
  static const FilterOperation greaterThan = FilterOperation._(5);
  static const FilterOperation greaterThanOrEquals = FilterOperation._(6);
  static const FilterOperation inList = FilterOperation._(7);
  static const FilterOperation matches = FilterOperation._(8);

  @Deprecated("Use equals instead")
  static const FilterOperation EQUAL = equals;
  @Deprecated("Use notEquals instead")
  static const FilterOperation NOT_EQUAL = notEquals;
  @Deprecated("Use lessThan instead")
  static const FilterOperation LESS_THAN = lessThan;
  @Deprecated("Use lessThanOrEquals instead")
  static const FilterOperation LESS_THAN_OR_EQUAL = lessThanOrEquals;
  @Deprecated("Use greaterThan instead")
  static const FilterOperation GREATER_THAN = greaterThan;
  @Deprecated("Use greaterThanOrEquals instead")
  static const FilterOperation GREATER_THAN_OR_EQUAL = greaterThanOrEquals;
  @Deprecated("Use inList instead")
  static const FilterOperation IN = inList;

  @override
  String toString() {
    switch (this) {
      case FilterOperation.equals:
        return "=";
      case FilterOperation.notEquals:
        return "!=";
      case FilterOperation.lessThan:
        return "<";
      case FilterOperation.lessThanOrEquals:
        return "<=";
      case FilterOperation.greaterThan:
        return ">";
      case FilterOperation.greaterThanOrEquals:
        return ">=";
      case FilterOperation.inList:
        return "IN";
      case FilterOperation.matches:
        return "MATCHES";
      default:
        throw "${this} not supported";
    }
  }
}

class ByKeyFilter extends Filter {
  var key;

  ByKeyFilter(this.key) : super();

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
