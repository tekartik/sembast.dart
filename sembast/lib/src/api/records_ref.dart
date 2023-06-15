import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable reference to multiple records
///
abstract class RecordsRef<K extends Key?, V extends Value?> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, null for new record.
  List<K> get keys;

  /// Cast if needed.
  RecordsRef<RK, RV> cast<RK extends Key?, RV extends Value?>();
}
