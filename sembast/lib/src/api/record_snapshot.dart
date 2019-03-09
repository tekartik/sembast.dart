import 'package:sembast/src/api/record_ref.dart';

/// A read record
abstract class RecordSnapshot<K, V> {
  /// Its reference
  RecordRef<K, V> get ref;

  /// The value
  V get value;
}
