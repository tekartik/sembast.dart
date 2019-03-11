import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/store_ref.dart';

///
/// An immutable reference to multiple records
///
abstract class RecordsRef<K, V> {
  /// Store reference
  StoreRef<K, V> get store;

  /// Record key, null for new record
  List<K> get keys;

  /// delete them record
  Future delete(DatabaseClient client);

  /// Cast if needed
  RecordsRef<RK, RV> cast<RK, RV>();

  /// Get all records values
  Future<List<V>> get(DatabaseClient client);

  /// Get all records snapshot
  Future<List<RecordSnapshot<K, V>>> getSnapshots(DatabaseClient client);
}
