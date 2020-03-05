import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_impl.dart';

/// @deprecated v2
///
/// Record
///
@deprecated
abstract class Record extends RecordSnapshot<dynamic, dynamic> {
  /// @deprecated v2
  ///
  /// true if the record has been deleted
  @deprecated
  bool get deleted;

  /// @deprecated v2
  ///
  /// its store
  /// 2019-03-06 Will be deprecated
  @deprecated
  SembastStore get store;

  /// @deprecated v2
  ///
  /// Create a record in a given [store] with a given [value] and
  /// an optional [key]
  ///
  @deprecated
  factory Record(SembastStore store, dynamic value, [dynamic key]) =>
      SembastRecord(store, value, key);

  /// @deprecated v2
  ///
  /// set the [value] of the specified [field]
  ///
  @deprecated
  void operator []=(String field, dynamic value);
}
