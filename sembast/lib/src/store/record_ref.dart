import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/store/store_ref.dart';

///
/// An immutable record reference
///
abstract class RecordRef<K, V> {
  /// Store reference
  StoreRef<K, V> get store;

  /// Record key, null for new record
  K get key;

  /// Create a snapshot of a record with a given value
  RecordSnapshot<K, V> snapshot(V value);

  /// Save a record, create if needed
  ///
  /// if [merge] is true and the field exists, data is merged
  Future<K> put(DatabaseClient client, V value, {bool merge});

  /// get a record from the database
  Future<RecordSnapshot<K, V>> get(DatabaseClient client);

  /// delete a record
  Future delete(DatabaseClient client);

  /// Cast if needed
  RecordRef<RK, RV> cast<RK, RV>();
}

/// A read record
abstract class RecordSnapshot<K, V> {
  /// Its reference
  RecordRef<K, V> get ref;

  /// The value
  V get value;
}
