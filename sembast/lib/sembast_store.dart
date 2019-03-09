import 'package:sembast/src/api/record_ref.dart';

///
/// Records
///
abstract class StoreRecord<K, V> {
  /// The record reference
  RecordRef<K, V> get ref;

  /// The key of the record
  K get key;

  /// its value (typically a map)
  V get value;

  ///
  /// for map records, get the value of the specified [field]
  ///
  dynamic operator [](String field);

  ///
  /// set the [value] of the specified [field]
  ///
  void operator []=(String field, dynamic value);

// factory StoreRecord(RecordRef<K, V> ref, V value) => RecordImpl(ref, value);
}
