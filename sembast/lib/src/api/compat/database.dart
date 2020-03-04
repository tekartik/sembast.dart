import 'package:sembast/src/api/compat/sembast.dart'; // ignore: deprecated_member_use_from_same_package

/// @deprecated v2
@deprecated
abstract class DatabaseCompat extends DatabaseExecutor {
  //
  // v2 Deprecated API below
  //

  /// @deprecated v2
  ///
  /// All the stores in the database
  @deprecated
  Iterable<Store> get stores;

  /// @deprecated v2
  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  @deprecated
  Store getStore(String storeName);

  /// @deprecated v2
  ///
  /// clear and delete a store
  ///
  @deprecated
  Future deleteStore(String storeName);

  /// @deprecated v2
  ///
  /// find existing store
  ///
  @deprecated
  Store findStore(String storeName);

  /// @deprecated v2
  ///
  /// Main store.
  ///
  @deprecated
  Store get mainStore;

  /// @deprecated v2
  ///
  /// Get current store names in the database.
  @deprecated
  Iterable<String> get storeNames;
}
