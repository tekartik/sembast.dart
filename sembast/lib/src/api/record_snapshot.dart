import 'package:sembast/src/api/protected/type.dart';
import 'package:sembast/src/api/record_ref.dart';

/// A read record
abstract class RecordSnapshot<K extends Key?, V extends Value?> {
  /// Its reference
  RecordRef<K, V> get ref;

  /// The key (shortcut to ref.key)
  K get key;

  /// The value
  V get value;

  /// Get the value of the specified [field].
  ///
  /// Will crash if attempting to access fields different than [Field.key] and
  /// [Field.value] if the value is not a map
  Object? operator [](String field);

  /// Cast if needed
  RecordSnapshot<RK, RV> cast<RK extends Key?, RV extends Value?>();
}
