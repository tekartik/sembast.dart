import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/utils.dart';

mixin RecordSnapshotMixin<K, V>
    implements RecordSnapshot<K, V>, SembastRecordValue<V> {
  @override
  RecordRef<K, V> ref;

  @override
  K get key => ref.key;

  @override
  V get value => rawValue;

  /// direct access to raw value
  @override
  V rawValue;

  @override
  String toString() => '$ref $rawValue';

  ///
  /// get the value of the specified [field]
  ///
  @override
  dynamic operator [](String field) => getValue(field);

  /// Safe value
  dynamic getValue(String field) {
    if (field == Field.value) {
      return value;
    } else if (field == Field.key) {
      return key;
    } else {
      return getMapFieldValue(value as Map, field);
    }
  }

  /// Only for read-only internal access
  dynamic getRawValue(String field) {
    if (field == Field.value) {
      return value;
    } else if (field == Field.key) {
      return key;
    } else {
      return getMapFieldRawValue(value as Map, field);
    }
  }

  @override
  RecordSnapshot<RK, RV> cast<RK, RV>() {
    if (this is RecordSnapshot<RK, RV>) {
      return this as RecordSnapshot<RK, RV>;
    }
    return ref.cast<RK, RV>().snapshot(value as RV);
  }
}

class SembastRecordSnapshot<K, V> with RecordSnapshotMixin<K, V> {
  SembastRecordSnapshot.fromRecord(ImmutableSembastRecord record) {
    this.ref = record.ref?.cast<K, V>();
    this.rawValue = record.value as V;
  }

  SembastRecordSnapshot(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this.rawValue = value;
  }
}

/// To use to avoid slow access to protected snapshot.
///
/// Used in filter
class SembastRecordRawSnapshot<K, V> implements RecordSnapshot<K, V> {
  final RecordSnapshotMixin<K, V> snapshot;

  SembastRecordRawSnapshot(RecordSnapshot<K, V> snapshot)
      : snapshot = snapshot as RecordSnapshotMixin<K, V>;

  /// Raw access to data
  @override
  dynamic operator [](String field) => snapshot.getRawValue(field);

  /// Raw access to data
  @override
  V get value => snapshot.rawValue;

  @override
  RecordSnapshot<RK, RV> cast<RK, RV>() =>
      SembastRecordRawSnapshot<RK, RV>(snapshot.cast<RK, RV>());

  @override
  K get key => snapshot.key;

  @override
  RecordRef<K, V> get ref => snapshot.ref;
}
