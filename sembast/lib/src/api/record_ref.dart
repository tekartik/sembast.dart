import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/database.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/store/record_ref_impl.dart';

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

  /// Update a record
  ///
  /// If it does not exist, return null
  Future<V> update(DatabaseClient client, V value);

  ///
  /// get a record from the database
  ///
  Future<RecordSnapshot<K, V>> get(DatabaseClient client);

  ///
  /// get a record value from the database
  ///
  Future<V> getValue(Database db);

  /// delete a record
  Future delete(DatabaseClient client);

  /// Cast if needed
  RecordRef<RK, RV> cast<RK, RV>();

  /// Create record ref
  factory RecordRef(StoreRef<K, V> store, K key) => RecordRefImpl(store, key);
}
