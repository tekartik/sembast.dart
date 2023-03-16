import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable record reference
///
abstract class RecordRef<K extends Key?, V extends Value?> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, never null.
  K get key;

  /// Cast if needed.
  RecordRef<RK, RV> cast<RK extends Key?, RV extends Value?>();
}
