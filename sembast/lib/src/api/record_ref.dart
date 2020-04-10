import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable record reference
///
abstract class RecordRef<K, V> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, null for new record.
  K get key;

  /// Cast if needed.
  RecordRef<RK, RV> cast<RK, RV>();
}
