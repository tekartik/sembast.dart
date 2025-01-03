import 'dart:async';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
import 'package:sembast/utils/database_utils.dart';

import 'import_common.dart';

/// Get the client implementation.
SembastDatabaseClient getClient(DatabaseClient client) =>
    client as SembastDatabaseClient;

/// Private interface
abstract class SembastDatabaseClient implements DatabaseClient {
  /// The current transaction if any (null for databases
  SembastDatabase get sembastDatabase;

  /// The current transaction if any (null for databases
  SembastTransaction? get sembastTransaction;

  /// Get the store, create if needed.
  SembastStore getSembastStore(StoreRef<Key?, Value?> ref);

  /// Will create a transaction if needed
  Future<T> inTransaction<T>(
      FutureOr<T> Function(SembastTransaction txn) action);
}

/// Database client extension methods.
extension SembastDatabaseClientExtension on DatabaseClient {
  /// Clear all records in the database.
  /// Close all existing listeners.
  Future<void> dropAll() async {
    var client = this.client;
    var db = client.sembastDatabase;
    await client.inTransaction((txn) async {
      var storeNames = db.storeNames.toList();
      for (var name in storeNames) {
        await db.txnDeleteStore(txn, name);
      }
    });
  }
}

/// Database client private extension methods.
extension SembastDatabaseClientPrvExt on DatabaseClient {
  /// Get the list of non empty store names.
  Iterable<String> get nonEmptyStoreNames =>
      getNonEmptyStoreNames(getClient(this).sembastDatabase);

  /// Get the client implementation.
  SembastDatabaseClient get client => getClient(this);
}
