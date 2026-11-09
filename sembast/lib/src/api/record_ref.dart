import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/store_ref.dart';

/// An immutable record reference
///
/// Get it with `store.record(key)`. It holds no data: pass the `Database` or
/// the `Transaction` to its methods.
///
/// ```dart
/// var record = store.record(key);
/// await record.put(db, value); // create or replace
/// await record.update(db, {'age': 5}); // change some fields (if it exists)
/// var current = await record.get(db); // null if not found
/// await record.delete(db);
/// ```
abstract class RecordRef<K extends Key?, V extends Value?> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, never null.
  K get key;

  /// Cast if needed.
  RecordRef<RK, RV> cast<RK extends Key?, RV extends Value?>();
}
