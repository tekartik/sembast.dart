import 'dart:async';

import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/compat/sembast.dart';
import 'package:sembast/src/api/compat/store.dart';
import 'package:sembast/src/api/transaction.dart';

export 'field.dart';

abstract class Database extends DatabaseExecutor implements DatabaseClient {
  Store get mainStore;

  /// Version of the database
  int get version;

  /// Database  path
  String get path;

  /// Get current store names in the database.
  Iterable<String> get storeNames;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future<T> transaction<T>(FutureOr<T> action(Transaction transaction));

  ///
  /// Close the database
  ///
  Future close();

  //
  // Deprecated API below
  //
  /// All the stores in the database
  Iterable<Store> get stores;

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  Store getStore(String storeName);

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName);

  ///
  /// find existing store
  ///
  Store findStore(String storeName);
}

/// can return a future or not
typedef OnVersionChangedFunction = FutureOr Function(
    Database db, int oldVersion, int newVersion);
