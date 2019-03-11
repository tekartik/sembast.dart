import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/utils.dart';

mixin RecordSnapshotMixin<K, V> implements RecordSnapshot<K, V> {
  @override
  RecordRef<K, V> ref;

  @override
  K get key => ref.key;

  @override
  V value;

  @override
  String toString() => '$ref $value';

  ///
  /// get the value of the specified [field]
  ///
  @override
  dynamic operator [](String field) {
    if (field == Field.value) {
      return value;
    } else if (field == Field.key) {
      return key;
    } else {
      return getMapFieldValue(value as Map, field);
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
    this.value = record.value as V;
  }

  SembastRecordSnapshot(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this.value = value;
  }
}
