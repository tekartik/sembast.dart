import 'package:sembast/src/api/compat/sembast.dart';

/// @deprecated v2
abstract class DatabaseCompat extends DatabaseExecutor {
  //
  // v2 Deprecated API below
  //

  /// @deprecated v2
  ///
  /// All the stores in the database
  Iterable<Store> get stores;

  /// @deprecated v2
  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  Store getStore(String storeName);

  /// @deprecated v2
  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  /// @deprecated v2
  ///
  /// find existing store
  ///
  Store findStore(String storeName);

  /// @deprecated v2
  ///
  /// Main store.
  ///
  Store get mainStore;

  /// @deprecated v2
  ///
  /// Get current store names in the database.
  Iterable<String> get storeNames;
}
