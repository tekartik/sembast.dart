import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/store.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/record_impl.dart';

///
/// Records
///
/// @deprecated v2
abstract class Record extends RecordSnapshot<dynamic, dynamic> {
  /// true if the record has been deleted
  bool get deleted;

  /// its store
  /// 2019-03-06 Will be deprecated
  /// @deprecated v2
  Store get store;

  ///
  /// Create a record in a given [store] with a given [value] and
  /// an optional [key]
  ///
  factory Record(Store store, dynamic value, [dynamic key]) =>
      SembastRecord(store, value, key);

  ///
  /// allow cloning a record to start modifying it
  ///
  Record clone({RecordRef<dynamic, dynamic> ref, dynamic value});

  ///
  /// set the [value] of the specified [field]
  ///
  void operator []=(String field, dynamic value);
}
