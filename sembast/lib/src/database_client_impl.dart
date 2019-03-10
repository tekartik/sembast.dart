import 'dart:async';

import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

SembastDatabaseClient getClient(DatabaseClient client) =>
    client as SembastDatabaseClient;

/// Private interface
abstract class SembastDatabaseClient {
  /// The current transaction if any (null for databases
  SembastDatabase get sembastDatabase;

  /// The current transaction if any (null for databases
  SembastTransaction get sembastTransaction;

  /// Get the store
  SembastStore getSembastStore(StoreRef ref);

  /// Will create a transaction if needed
  Future<T> inTransaction<T>(FutureOr<T> action(SembastTransaction txn));
}
