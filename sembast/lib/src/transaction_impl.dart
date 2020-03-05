import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/compat/sembast.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';

// ignore_for_file: deprecated_member_use_from_same_package

mixin DatabaseExecutorMixin implements DatabaseExecutor, StoreExecutor {}

/// Transaction implementation.
class SembastTransaction extends Object
    with DatabaseExecutorMixin
    implements Transaction, SembastDatabaseClient {
  /// The database.
  @override
  final SembastDatabase sembastDatabase;

  /// The transaction id.
  int get id => _id;

  final int _id;

  /// make the completer async as the Transaction following
  /// action is not a priority
  Completer completer = Completer();

  /// Constructor.
  SembastTransaction(this.sembastDatabase, this._id);

  /// True if completed.
  bool get isCompleted => completer.isCompleted;

  /// Completed future.
  Future get completed => completer.future;

  @override
  String toString() {
    return 'txn ${_id}${completer.isCompleted ? ' completed' : ''}';
  }

  /// Make it an executor.
  SembastTransactionStore toExecutor(Store store) => store != null
      ? SembastTransactionStore(this, store as SembastStore)
      : null;

  /// Delete a store
  Future deleteStore(String storeName) =>
      database.txnDeleteStore(this, storeName);

  /// Find a store
  StoreExecutor findStore(String storeName) =>
      database.txnFindStore(this, storeName);

  /// local helper
  SembastDatabase get database => sembastDatabase;

  @override
  Future<T> inTransaction<T>(
          FutureOr<T> Function(SembastTransaction transaction) action) async =>
      action(this);

  @override
  SembastTransaction get sembastTransaction => this;

  @override
  SembastStore getSembastStore(StoreRef ref) =>
      database.txnGetStore(this, ref.name).store;
}

/// Store implementation.
class SembastTransactionStore implements StoreTransaction {
  /// Transaction.
  final SembastTransaction sembastTransaction;

  /// Store
  final SembastStore store;

  /// Constructor.
  SembastTransactionStore(this.sembastTransaction, this.store);

  @override
  String toString() {
    return '${store}';
  }
}
