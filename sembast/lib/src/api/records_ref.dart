import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable reference to multiple records
///
abstract class RecordsRef<K, V> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, null for new record.
  List<K> get keys;

  /// Record ref at a given index.
  RecordRef<K, V> operator [](int index);

  /// delete them.
  Future<void> delete(DatabaseClient client);

  /// Cast if needed.
  RecordsRef<RK, RV> cast<RK, RV>();

  /// Get all records values.
  Future<List<V?>> get(DatabaseClient client);

  /// Get all records snapshot.
  Future<List<RecordSnapshot<K, V>?>> getSnapshots(DatabaseClient client);

  /// Save multiple records, creating the one needed.
  ///
  /// if [merge] is true and the field exists, data is merged.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns the updated values.
  Future<List<V>> put(DatabaseClient client, List<V> values, {bool? merge});

  /// Update multiple records.
  ///
  /// if value is a map, keys with dot values
  /// refer to a path in the map, unless the key is specifically escaped.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns the list of updated values, a value being null if the record
  /// does not exist.
  Future<List<V>> update(DatabaseClient client, List<V> values);

  /// Create records that don't exist.
  ///
  /// The list of [values] must match the list of keys.
  ///
  /// Returns a list of the keys, if not inserted, a key is null.
  Future<List<K>> add(DatabaseClient client, List<V> values);
}
