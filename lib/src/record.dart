import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';

///
/// Special field access
///
class Field {
  /*
  static const String value = "_value";
  static const String key = "_key";
  static String VALUE = "_value";
  static String KEY = "_key";

  */
  static String value = "_value";
  static String key = "_key";

  // use value instead
  @deprecated
  static String VALUE = value;

  // use key instead
  @deprecated
  static String KEY = key;
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
      new SembastRecord(store, value, key);
}
