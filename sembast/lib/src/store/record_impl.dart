import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/api/record_ref.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/utils.dart';

mixin RecordMixin<K, V> implements Record<K, V> {
  @override
  RecordRef<K, V> ref;

  @override
  K get key => ref.key;

  V _value;

  @override
  V get value => _value;

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

  ///
  /// set the [value] of the specified [field]
  ///
  @override
  void operator []=(String field, dynamic value) {
    if (field == Field.value) {
      _value = value as V;
    } else if (field == Field.key) {
      ref = ref.store.record(value as K);
    } else {
      if (!(_value is Map)) {
        // This will throw if V is not a map
        _value = <String, dynamic>{} as V;
      }
      setMapFieldValue(_value as Map, field, value);
    }
  }

  set value(V value) => _value = sanitizeValue(value) as V;
}

class RecordImpl<K, V> with RecordMixin<K, V> {
  RecordImpl(RecordRef<K, V> ref, V value) {
    this.ref = ref;
    this._value = cloneValue(value) as V;
  }
}
