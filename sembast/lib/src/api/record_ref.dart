import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable record reference
///
abstract class RecordRef<K, V> {
  /// Store reference
  StoreRef<K, V> get store;

  /// Record key, null for new record
  K get key;

  /// Save a record, create if needed
  ///
  /// if [merge] is true and the field exists, data is merged
  Future<K> put(DatabaseClient client, V value, {bool merge});

  /// Update a record
  ///
  /// If it does not exist, return null
  Future<V> update(DatabaseClient client, V value);

  ///
  /// get a record value from the database
  ///
  Future<V> get(DatabaseClient client);

  ///
  /// get a record snapshot from the database
  ///
  Future<RecordSnapshot<K, V>> getSnapshot(DatabaseClient client);

  /// delete a record
  Future delete(DatabaseClient client);

  /// Cast if needed
  RecordRef<RK, RV> cast<RK, RV>();

  /// Create record ref
// factory RecordRef(StoreRef<K, V> store, K key) => RecordRefImpl(store, key);
}
