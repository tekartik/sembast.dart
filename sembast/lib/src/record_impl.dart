import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/utils.dart';

import 'import_common.dart';
import 'store_ref_impl.dart';

///
/// Internal Record, either in store or in transaction
///
abstract class SembastRecord extends RecordSnapshot<Key?, Value?> {
  ///
  /// true if the record has been deleted
  bool get deleted;
}

/// Sembast record helper mixin.
mixin SembastRecordHelperMixin implements SembastRecord {
  ///
  /// Copy a record.
  ///
  ImmutableSembastRecord sembastClone({
    SembastStore? store,
    dynamic key,
    RecordRef<Key?, Value?>? ref,
    dynamic value,
    required bool deleted,
  }) {
    return ImmutableSembastRecord(
      ref ?? this.ref,
      (value ?? this.value) as Map,
      deleted: deleted,
    );
  }

  /// Clone as deleted.
  ImmutableSembastRecord sembastCloneAsDeleted() {
    return ImmutableSembastRecord.noValue(ref, deleted: true);
  }

  Map<String, Object?> _toBaseMap() {
    var map = <String, Object?>{};
    map[dbRecordKey] = key;

    if (deleted) {
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
    if (!deleted) {
      map[dbRecordValueKey] = value;
    }
    return map;
  }

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(other) {
    if (other is SembastRecord) {
      return key == other.key;
    }
    return false;
  }
}

/// Used as an interface
abstract class SembastRecordValue<V extends Value?> {
  /// Raw value/
  late V rawValue;
}

/// Sembast record mixin.
mixin SembastRecordMixin implements SembastRecord, SembastRecordValue {
  bool? _deleted;

  @override
  bool get deleted => _deleted == true;

  set deleted(bool deleted) => _deleted = deleted;

  set value(Value? value) => rawValue = sanitizeValueIfMap(value as Value);
}

/// Immutable record in jdb.
class ImmutableSembastRecordJdb extends ImmutableSembastRecord {
  /// Immutable record in jdb.
  ///
  /// revision needed
  ///
  /// [value] can be null for deleted
  ImmutableSembastRecordJdb(
    super.ref,
    super.value, {
    super.deleted,
    required int revision,
  }) {
    this.revision = revision;
  }
}

/// Immutable record, used in storage
class ImmutableSembastRecord
    with
        SembastRecordMixin,
        SembastRecordHelperMixin,
        RecordSnapshotMixin<Key?, Value?> {
  @override
  set value(dynamic value) {
    throw StateError('Record is immutable. Clone to modify it');
  }

  @override
  Key get key => super.key as Key;

  @override
  Value get value => immutableValue(super.value as Value);

  static var _lastRevision = 0;

  int _makeRevision() {
    return ++_lastRevision;
  }

  /// Record from row map.
  ImmutableSembastRecord.fromDatabaseRowMap(Map map) {
    final storeName = map[dbStoreNameKey] as String?;
    final storeRef =
        storeName == null
            ? mainStoreRef
            : SembastStoreRef<Key, Value>(storeName);
    var key = map[dbRecordKey] as Key?;
    var value = map[dbRecordValueKey] as Value?;
    if (key == null) {
      throw StateError('Invalid map key in map');
    }
    ref = storeRef.record(key);
    _deleted = map[dbRecordDeletedKey] == true;
    if (!deleted) {
      if (value == null) {
        throw StateError('Invalid map value in $map');
      }
      super.value = sanitizeValueIfMap(value);
    }
    revision = _makeRevision();
  }

  ///
  /// Create a record at a given [ref] with a given [value] and
  /// We know data has been sanitized before
  /// an optional [key]
  ///
  /// value is null for deleted record only
  ///
  ImmutableSembastRecord(
    RecordRef<Key?, Value?> ref,
    Value? value, {
    bool deleted = false,
  }) {
    this.ref = ref;
    _deleted = deleted;
    if (!deleted) {
      super.value = value!;
    }
    revision = _makeRevision();
  }

  ///
  /// Create a record at a given [ref] without value (access would crash)
  ///
  /// value is null for deleted record
  ///
  ImmutableSembastRecord.noValue(
    RecordRef<Key?, Value?> ref, {
    bool deleted = false,
  }) {
    this.ref = ref;
    _deleted = deleted;
    if (deleted) {
      revision = _makeRevision();
    }
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
  Key get key => record.key;

  @override
  Value get value => record.value;

  @override
  RecordRef<Key?, Value?> get ref => record.ref;

  @override
  RecordSnapshot<RK, RV> cast<RK extends Key?, RV extends Value?>() =>
      record.cast<RK, RV>();

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
  ImmutableSembastRecord record,
) {
  if (record is ImmutableSembastRecordJdb) {
    return record;
  }
  // no revision
  return ImmutableSembastRecordJdb(
    record.ref,
    record.deleted ? null : cloneValue(record.value),
    deleted: record.deleted,
    revision: record.revision!,
  );
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
  return SembastRecordSnapshot(record.ref, cloneValue(record.value as Value));
}
