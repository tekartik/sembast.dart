import 'package:sembast/sembast.dart';
import 'package:sembast/src/database.dart';
import 'package:sembast/src/record.dart';
import 'package:sembast/src/sembast_impl.dart';
import 'package:sembast/src/store/record_ref.dart';
import 'package:sembast/src/store/store_ref.dart';
import 'package:sembast/src/utils.dart';

mixin SembastRecordWithStoreMixin implements Record {
  // Kept for compatibility
  @override
  Store store;
}
mixin SembastRecordHelperMixin implements Record {
  ///
  /// allow cloning a record to start modifying it
  ///
  @override
  Record clone({RecordRef<dynamic, dynamic> ref, dynamic value}) =>
      MutableSembastRecord(ref ?? this.ref, value ?? this.value);

  ///
  /// allow cloning a record to start modifying it
  ///
  ImmutableSembastRecord sembastClone(
      {Store store,
      dynamic key,
      RecordRef<dynamic, dynamic> ref,
      dynamic value,
      bool deleted}) {
    return ImmutableSembastRecord(ref ?? this.ref, value ?? this.value,
        deleted: deleted);
  }

  /*
    if (ref == null) {
      if (!(this is ImmutableSembastRecord)) {
        store ??= this.store;
      }
      return SembastRecord.copy(
          store: store,
          key: key ?? this.key,
          value: value ?? this.value,
          deleted: deleted ?? this.deleted,
          ref: ref ?? this.ref);
    } else {
      // Forget store here
      return SembastRecord(null, cloneValue(value ?? this.value));
    }
    */

  Map<String, dynamic> _toBaseMap() {
    var map = <String, dynamic>{};
    map[dbRecordKey] = key;

    if (deleted == true) {
      map[dbRecordDeletedKey] = true;
    }
    if (ref.store != null && ref.store != mainStoreRef) {
      map[dbStoreNameKey] = ref.store.name;
    }
    return map;
  }

  // The actual map written to disk
  Map<String, dynamic> toDatabaseRowMap() {
    var map = _toBaseMap();
    map[dbRecordValueKey] = value;
    return map;
  }

  @override
  String toString() {
    return toDatabaseRowMap().toString();
  }

  @override
  int get hashCode => key == null ? 0 : key.hashCode;

  @override
  bool operator ==(o) {
    if (o is Record) {
      return key == null ? false : (key == o.key);
    }
    return false;
  }
}
mixin SembastRecordMixin implements Record {
  @override
  RecordRef<dynamic, dynamic> ref;

  @override
  dynamic get key => ref.key;

  var _value;
  bool _deleted;

  @override
  dynamic get value => _value;

  @override
  bool get deleted => _deleted == true;

  set deleted(bool deleted) => _deleted = deleted;

  ///
  /// get the value of the specified [field]
  ///
  @override
  dynamic operator [](String field) {
    if (field == Field.value) {
      return _value;
    } else if (field == Field.key) {
      return key;
    } else {
      return getMapFieldValue(_value as Map, field);
    }
  }

  set value(value) => _value = sanitizeValue(value);
}

/// Record that can modified although not cloned right away
class LazyMutableSembastRecord with SembastRecordHelperMixin implements Record {
  // For compatibility
  // Will be remove in 2.0
  @override
  Store store;

  // Can change overtime if modified
  Record record;

  LazyMutableSembastRecord(this.store, this.record) {
    assert(record != null);
    assert(!(record is LazyMutableSembastRecord));
  }

  @override
  void operator []=(String field, value) {
    // Mutate if needed
    mutableRecord[field] = value;
  }

  /// Mutate only once
  Record get mutableRecord {
    if (record is ImmutableSembastRecord) {
      var immutable = record as ImmutableSembastRecord;
      // Clone it as compatibility SembastRecord
      record = SembastRecord(store, cloneValue(immutable._value), record.key);
    }
    return record;
  }

  @override
  dynamic operator [](String field) {
    var value = record[field];

    if (record is ImmutableSembastRecord) {
      // Need mutation?
      if (isValueMutable(value)) {
        return mutableRecord[field];
      }
    }
    return value;
  }

  @override
  bool get deleted => record.deleted;

  @override
  dynamic get key => record.key;

  /// We allow the target to modify the map so clone it
  @override
  dynamic get value => mutableRecord.value;

  @override
  RecordRef get ref => record.ref;
}

/// Immutable record, used in storage
class ImmutableSembastRecord with SembastRecordMixin, SembastRecordHelperMixin {
  @override
  void operator []=(String field, value) {
    throw StateError('Record is immutable. Clone to modify it');
  }

  @override
  set value(value) {
    throw StateError('Record is immutable. Clone to modify it');
  }

  @override
  dynamic get value => immutableValue(_value);

  ImmutableSembastRecord.fromDatabaseRowMap(Database db, Map map) {
    String storeName = map[dbStoreNameKey] as String;
    StoreRef<dynamic, dynamic> storeRef = storeName == null
        ? mainStoreRef
        : StoreRef<dynamic, dynamic>(storeName);
    this.ref = storeRef.record(map[dbRecordKey]);
    _value = sanitizeValue(map[dbRecordValueKey]);
    _deleted = map[dbRecordDeletedKey] == true;
  }

  ///
  /// Create a record at a given [ref] with a given [value] and
  /// We know data has been sanitized before
  /// an optional [key]
  ///
  ImmutableSembastRecord(RecordRef<dynamic, dynamic> ref, dynamic value,
      {bool deleted}) {
    this.ref = ref;
    this._value = value;
    this._deleted = deleted;
  }

  @override
  @deprecated
  Store get store => throw UnsupportedError(
      'Deprecated for immutable record. use ref.store instead');
}

class TxnRecord with SembastRecordHelperMixin implements Record {
  // Can change overtime if modified
  ImmutableSembastRecord record;

  TxnRecord(this.store, this.record);

  @override
  void operator []=(String field, value) =>
      throw UnsupportedError('Not supported for txn records');

  @override
  dynamic operator [](String field) => record[field];

  @override
  bool get deleted => record.deleted;

  @override
  dynamic get key => record.key;

  @override
  Store store;

  @override
  dynamic get value => record.value;

  @override
  RecordRef get ref => record.ref;
}

mixin MutableSembastRecordMixin implements Record {
  set value(dynamic value);

  set ref(RecordRef<dynamic, dynamic> ref);

  ///
  /// set the [value] of the specified [field]
  ///
  void setField(String field, dynamic value) {
    if (field == Field.value) {
      this.value = value;
    } else if (field == Field.key) {
      ref = ref.store.record(value);
    } else {
      if (!(value is Map)) {
        this.value = {};
      }
      setMapFieldValue(this.value as Map, field, value);
    }
  }
}

class MutableSembastRecord
    with
        SembastRecordMixin,
        SembastRecordHelperMixin,
        MutableSembastRecordMixin {
  ///
  /// Create a record at a given [ref] with a given [value] and
  /// We know data has been sanitized before
  /// an optional [key]
  ///
  MutableSembastRecord(RecordRef<dynamic, dynamic> ref, dynamic value) {
    this.ref = ref;
    this._value = value;
  }

  @override
  void operator []=(String field, value) => setField(field, value);

  @override
  Store get store =>
      throw UnsupportedError('Deprecated. use ref.store instead');
}

class SembastRecord
    with
        SembastRecordMixin,
        SembastRecordHelperMixin,
        SembastRecordWithStoreMixin {
  ///
  /// set the [value] of the specified [field]
  ///
  @override
  void operator []=(String field, var value) {
    if (field == Field.value) {
      _value = value;
    } else if (field == Field.key) {
      ref = ref.store.record(value);
    } else {
      if (!(_value is Map)) {
        _value = {};
      }
      setMapFieldValue(_value as Map, field, value);
    }
  }

  ///
  /// check whether the map specified looks like a record
  ///
  static bool isMapRecord(Map map) {
    var key = map[dbRecordKey];
    return (key != null);
  }

  ///
  /// Create a record in a given [store] with a given [value] and
  /// We know data has been sanitized before
  /// an optional [key]
  ///
  SembastRecord(Store store, dynamic value, [dynamic key]) {
    /// Store kept for compatibility
    this.store = store;
    this.value = value;
    this.ref = (store?.ref ?? mainStoreRef).record(key);
  }
}

/// Convert to immultable if needed
ImmutableSembastRecord makeImmutableRecord(Record record) {
  if (record is ImmutableSembastRecord) {
    return record;
  } else if (record == null) {
    // This can happen when settings boundary
    return null;
  }
  return ImmutableSembastRecord(record.ref, cloneValue(record.value),
      deleted: record.deleted);
}

LazyMutableSembastRecord makeLazyMutableRecord(
        Store store, ImmutableSembastRecord record) =>
    LazyMutableSembastRecord(store, record);
