import 'package:sembast/src/store/record_impl.dart';
import 'package:sembast/src/store/record_ref.dart';

export 'package:sembast/src/store/record_ref.dart'
    show RecordRef, RecordSnapshot;
export 'package:sembast/src/store/store_ref.dart'
    show StoreRef, intMapStoreFactory, stringMapStoreFactory;
export 'sembast.dart' show Database;

///
/// Records
///
abstract class Record<K, V> {
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

  factory Record(RecordRef<K, V> ref, V value) => RecordImpl(ref, value);
}

///
/// Database client (either Database or Transaction)
///
abstract class DatabaseClient {}
