import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store/record_ref.dart';
import 'package:sembast/sembast_store.dart' as store;

///
/// Records
///
abstract class Record extends store.Record<dynamic, dynamic> {
  /// true if the record has been deleted
  bool get deleted;

  /// its store
  /// 2019-03-06 Will be deprecated
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
}
