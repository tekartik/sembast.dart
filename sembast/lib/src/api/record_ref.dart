import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;

///
/// An immutable record reference
///
abstract class RecordRef<K, V> {
  /// Store reference.
  StoreRef<K, V> get store;

  /// Record key, null for new record.
  K get key;

  /// Create a snapshot of a record with a given value.
  RecordSnapshot<K, V> snapshot(V value);

  /// Create a record if it does not exist.
  ///
  /// Returns the key if inserted, null otherwise.
  Future<K> add(DatabaseClient client, V value);

  /// Save a record, create if needed.
  ///
  /// if [merge] is true and the field exists, data is merged
  ///
  /// Returns the updated value.
  Future<V> put(DatabaseClient client, V value, {bool merge});

  /// Update a record.
  ///
  /// If it does not exist, return null. if value is a map, keys with dot values
  /// refer to a path in the map, unless the key is specifically escaped
  ///
  /// Returns the updated value.
  Future<V> update(DatabaseClient client, V value);

  /// Get a record value from the database.
  Future<V> get(DatabaseClient client);

  /// Get a record snapshot from the database.
  Future<RecordSnapshot<K, V>> getSnapshot(DatabaseClient client);

  /// Get a stream of a record snapshot from the database.
  ///
  /// It allows listening to a single instance of a record.
  Stream<RecordSnapshot<K, V>> onSnapshot(v2.Database database);

  /// Delete a record.
  Future delete(DatabaseClient client);

  /// Cast if needed.
  RecordRef<RK, RV> cast<RK, RV>();

  /// Return true if the record exists.
  Future<bool> exists(DatabaseClient client);
}

/// An enumeration of record change types.
enum RecordChangeType {
  /// Indicates a new record was added to the set of documents matching the
  /// query.
  added,

  /// Indicates a record within the query was modified.
  modified,

  /// Indicates a record within the query was removed (either deleted or no
  /// longer matches the query).
  removed,
}

/// Record change information.
abstract class RecordChange<K, V> {
  /// The type of change that occurred (added, modified, or removed).
  RecordChangeType get type;

  /// The record affected by this change, null if deleted.
  RecordSnapshot<K, V> get record;

  /// The record reference affected by this change.
  RecordRef<K, V> get ref;

  /// Cast if needed
  RecordSnapshot<RK, RV> cast<RK, RV>();
}
