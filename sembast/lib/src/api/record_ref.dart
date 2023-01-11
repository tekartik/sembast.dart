import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';

/// Base key.
typedef RecordKeyBase = Object;

/// Base value.
typedef RecordValueBase = Object;

/// Internal shortcut.
typedef Key = RecordKeyBase;

/// Internal shortcut.
typedef Value = RecordValueBase;

///
/// An immutable record reference
///
abstract class RecordRef<K, V> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, never null.
  K get key;

  /// Cast if needed.
  RecordRef<RK, RV> cast<RK, RV>();
}
