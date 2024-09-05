import 'package:sembast/src/import_common.dart';
import 'package:sembast/src/sembast_impl.dart' show dbMainStore;
import 'package:sembast/src/store_ref_impl.dart';

/// Don't throw exception yet. will be done in the future.
const checkStoreKeyThrowException = false;

/// Print a warning if a store key is not a String or an int, to enable in the future.
const checkStoreKey = false;

var _debugCheckStoreKeyPrinted = <String, bool>{};

bool _checkStoreKey<K>(String name) {
  /// Type Object is supported for compatibility
  if (K == String || K == int) {
    return true;
  }

  final text = '''
*** WARNING ***

Invalid key type $K.
Only String and int are supported. See https://github.com/tekartik/sembast.dart/blob/master/sembast/README.md#keys for details

Recommendation is to create a store with an explicit type StoreRef<String, ...> or StoreRef<int, ...> or using intMapStoreFactor or stringMapStoreFactory
This will throw an exception in the future. For now it is displayed once per store.

    ''';
  try {
    throw ArgumentError(text);
  } catch (e, st) {
    if (checkStoreKeyThrowException) {
      rethrow;
    } else {
      final printed = _debugCheckStoreKeyPrinted[name] ?? false;
      if (!printed) {
        _debugCheckStoreKeyPrinted[name] = true;
        // ignore: avoid_print
        print(text);
        // ignore: avoid_print
        print(st);
      }
    }
  }
  return true;
}

/// A pointer to a store.
///
abstract class StoreRef<K extends Key?, V extends Value?> {
  /// The name of the store
  String get name;

  /// Create a record reference.
  ///
  /// Key cannot be null.
  RecordRef<K, V> record(K key);

  /// Create a reference to multiple records
  ///
  RecordsRef<K, V> records(Iterable<K> keys);

  /// A null name means a the main store.
  ///
  /// A name must not start with `_` (besides the main store).
  factory StoreRef(String name) {
    if (checkStoreKey) {
      assert(_checkStoreKey<K>(dbMainStore));
    }
    return SembastStoreRef<K, V>(name);
  }

  /// A pointer to the main store
  factory StoreRef.main() {
    if (checkStoreKey) {
      assert(_checkStoreKey<K>(dbMainStore));
    }
    return SembastStoreRef<K, V>(dbMainStore);
  }

  /// Cast if needed
  StoreRef<RK, RV> cast<RK extends Key?, RV extends Value?>();
}

/// Store factory interface
abstract class StoreFactory<K extends Key?, V extends Value?> {
  /// Creates a reference to a store.
  StoreRef<K, V> store(String name);
}

/// Store factory with key as int and value as Map
final intMapStoreFactory = StoreFactoryBase<int, Map<String, Object?>>();

/// Store factory with key as String and value as Map
final stringMapStoreFactory = StoreFactoryBase<String, Map<String, Object?>>();
