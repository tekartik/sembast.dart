import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';

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
