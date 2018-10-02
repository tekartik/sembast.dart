import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

///
/// Special field access
///
class Field {
  /// Our value field
  static String value = "_value";

  /// Our key field
  static String key = "_key";
}

///
/// Records
///
abstract class Record {
  /// The key of the record
  get key;

  /// its value (typically a map)
  get value;

  /// true if the record has been deleted
  bool get deleted;

  /// its store
  Store get store;

  ///
  /// get the value of the specified [field]
  ///
  operator [](String field);

  ///
  /// set the [value] of the specified [field]
  ///
  void operator []=(String field, var value);

  ///
  /// Create a record in a given [store] with a given [value] and
  /// an optional [key]
  ///
  factory Record(Store store, dynamic value, [dynamic key]) =>
      SembastRecord(store, value, key);
}
