import 'dart:async';

import 'import_common.dart';

/// Record change info streamed during `StoreRef.onChange`.
///
/// Handle both add, update and delete
abstract class RecordChange<K extends Key, V extends Value> {
  /// The previous record snapshot, null for record added.
  RecordSnapshot<K, V>? get oldSnapshot;

  /// The new record value, null for record removed
  RecordSnapshot<K, V>? get newSnapshot;

  /// Cast if needed
  RecordChange<RK, RV> cast<RK extends Key, RV extends Value>();
}

/// Record change listener
typedef TransactionRecordChangeListener<K extends Key, V extends Value>
    = FutureOr<void> Function(
        Transaction transaction, List<RecordChange<K, V>> changes);

/// Record change helper.
extension SembastRecordChangeExtension<K extends Key, V extends Value>
    on RecordChange<K, V> {
  /// The previous record value, null for record added.
  V? get oldValue => oldSnapshot?.value;

  /// The new record value, null for record removed
  V? get newValue => newSnapshot?.value;

  /// True if the record was added.
  bool get isAdd => oldValue == null;

  /// true if the record was deleted.
  bool get isDelete => newValue == null;

  /// True if the record was updated.
  bool get isUpdate => !isAdd && !isDelete;

  /// The record ref.
  RecordRef<K, V> get ref => (newSnapshot?.ref ?? oldSnapshot?.ref)!;
}
