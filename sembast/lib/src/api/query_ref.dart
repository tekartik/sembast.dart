import 'package:sembast/src/api/sembast.dart';

/// A query on a store.
abstract class QueryRef<K, V> {
  /// Find multiple records and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(Database database);

  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client);

  /// Find first record (null if none) and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<RecordSnapshot<K, V>?> onSnapshot(Database database);

  /// Find first record matching the query.
  ///
  /// Returns null if none found.
  Future<RecordSnapshot<K, V>?> getSnapshot(DatabaseClient client);
}
