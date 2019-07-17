import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;

// New in 1.16

///
/// A query on a store.
///
abstract class QueryRef<K, V> {
  ///
  /// Find multiple records and listen for changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  ///
  Stream<List<RecordSnapshot<K, V>>> onSnapshots(v2.Database database);

  ///
  /// Find multiple records.
  ///
  /// Returns an empty array if none found.
  ///
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client);
}
