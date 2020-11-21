import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/record_snapshot.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/utils.dart';

///
/// Internal Record, either in store or in transaction
///
abstract class SembastRecord extends RecordSnapshot<dynamic, dynamic> {
  ///
  /// true if the record has been deleted
  bool get deleted;
}

/// Sembast record helper mixin.
mixin SembastRecordHelperMixin implements SembastRecord {
  ///
  /// Copy a record.
  ///
  ImmutableSembastRecord sembastClone(
      {SembastStore? store,
      dynamic key,
      RecordRef<dynamic, dynamic>? ref,
      dynamic value,
      required bool deleted}) {
    return ImmutableSembastRecord(ref ?? this.ref, (value ?? this.value) as Map,
        deleted: deleted);
  }

  /// Clone as deleted.
  ImmutableSembastRecord sembastCloneAsDeleted() {
    return ImmutableSembastRecord(ref, null, deleted: true);
  }

  Map<String, Object?> _toBaseMap() {
    var map = <String, Object?>{};
    map[dbRecordKey] = key;

    if (deleted == true) {
      map[dbRecordDeletedKey] = true;
    }
    if (ref.store != mainStoreRef) {
      map[dbStoreNameKey] = ref.store.name;
    }
    return map;
  }

  /// The actual map written to disk
  Map<String, Object?> toDatabaseRowMap() {
    var map = _toBaseMap();
    // Don't write the value for deleted
    // ...and for null too anyway...
    if (value != null && !deleted) {
      map[dbRecordValueKey] = value;
    }
    return map;
  }

  @override
  int get hashCode => key == null ? 0 : key.hashCode;

  @override
  bool operator ==(o) {
    if (o is SembastRecord) {
      return key == null ? false : (key == o.key);
    }
    return false;
  }
}

/// Used as an interface
abstract class SembastRecordValue<V> {
  /// Raw value/
  late V rawValue;
}

/// Sembast record mixin.
mixin SembastRecordMixin implements SembastRecord, SembastRecordValue {
  bool? _deleted;

  @override
  bool get deleted => _deleted == true;

  set deleted(bool deleted) => _deleted = deleted;

  set value(value) => rawValue = sanitizeValueIfMap(value);
}

/// Immutable record in jdb.
class ImmutableSembastRecordJdb extends ImmutableSembastRecord {
  /// Immutable record in jdb.
  ///
  /// revision needed
  ImmutableSembastRecordJdb(RecordRef ref, dynamic value,
      {bool deleted = false, required int revision})
      : super(ref, value, deleted: deleted) {
    this.revision = revision;
  }
}

/// Immutable record, used in storage
class ImmutableSembastRecord
    with SembastRecordMixin, SembastRecordHelperMixin, RecordSnapshotMixin {
  @override
  set value(dynamic value) {
    throw StateError('Record is immutable. Clone to modify it');
  }

  @override
  Object? get value => immutableValue(super.value);

  static var _lastRevision = 0;

  int _makeRevision() {
    return ++_lastRevision;
  }

  /// Record from row map.
  ImmutableSembastRecord.fromDatabaseRowMap(Database db, Map map) {
    final storeName = map[dbStoreNameKey] as String?;
    final storeRef = storeName == null
        ? mainStoreRef
        : StoreRef<dynamic, dynamic>(storeName);
    ref = storeRef.record(map[dbRecordKey]);
    super.value = sanitizeValueIfMap(map[dbRecordValueKey]);
    _deleted = map[dbRecordDeletedKey] == true;
    revision = _makeRevision();
  }

  ///
  /// Create a record at a given [ref] with a given [value] and
  /// We know data has been sanitized before
  /// an optional [key]
  ///
  /// value is null for deleted record
  ///
  ImmutableSembastRecord(RecordRef<dynamic, dynamic> ref, Object? value,
      {bool deleted = false}) {
    this.ref = ref;
    super.value = value;
    _deleted = deleted;
    revision = _makeRevision();
  }

  @override
  String toString() {
    var map = toDatabaseRowMap();
    if (revision != null) {
      map['revision'] = revision;
    }
    return map.toString();
  }
}

/// Transaction record.
class TxnRecord with SembastRecordHelperMixin implements SembastRecord {
  /// Can change overtime if modified
  ImmutableSembastRecord record;

  /// Transaction record.
  TxnRecord(this.record);

  @override
  dynamic operator [](String? field) => record[field!];

  @override
  bool get deleted => record.deleted;

  @override
  dynamic get key => record.key;

  @override
  dynamic get value => record.value;

  @override
  RecordRef get ref => record.ref;

  @override
  RecordSnapshot<RK, RV> cast<RK, RV>() => record.cast<RK, RV>();

  /// non deleted record.
  ImmutableSembastRecord? get nonDeletedRecord => deleted ? null : record;
}

///
/// check whether the map specified looks like a record
///
bool isMapRecord(Map map) {
  var key = map[dbRecordKey];
  return (key != null);
}

/// Convert to immutable if needed
ImmutableSembastRecordJdb makeImmutableRecordJdb(
    ImmutableSembastRecord record) {
  if (record is ImmutableSembastRecordJdb) {
    return record;
  }
  // no revision
  return ImmutableSembastRecordJdb(record.ref, cloneValue(record.value),
      deleted: record.deleted, revision: record.revision!);
}

/// Make immutable snapshot.
RecordSnapshot? makeImmutableRecordSnapshot(RecordSnapshot? record) {
  if (record is ImmutableSembastRecord) {
    return record;
  } else if (record is SembastRecordSnapshot) {
    return record;
  } else if (record == null) {
    // This can happen when settings boundary
    return null;
  }
  return SembastRecordSnapshot(record.ref, cloneValue(record.value));
}

/// create snapshot list.
List<SembastRecordSnapshot<K, V>> immutableListToSnapshots<K, V>(
    List<ImmutableSembastRecord> records) {
  return records
      .map((immutable) => SembastRecordSnapshot<K, V>.fromRecord(immutable))
      .toList(growable: false);
}
