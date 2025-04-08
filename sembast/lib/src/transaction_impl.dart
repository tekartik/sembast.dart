import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';

import 'import_common.dart';

/// Warning when using database object in transaction in debug mode
/// could become the default one day
var debugSembastWarnDatabaseCallInTransaction = false; // devFalse;

/// Key is the database object
class DebugSembastTransactionZoneInfo {
  @override
  String toString() {
    return 'Database in transaction';
  }
}

/// Transaction implementation.
class SembastTransaction extends Object
    implements Transaction, SembastDatabaseClient {
  /// The database.
  @override
  final SembastDatabase sembastDatabase;

  /// The transaction id.
  int get id => _id;

  final int _id;

  /// make the completer async as the Transaction following
  /// action is not a priority
  final completer = Completer<void>();

  /// Constructor.
  SembastTransaction(this.sembastDatabase, this._id);

  /// True if completed.
  bool get isCompleted => completer.isCompleted;

  /// Completed future.
  Future get completed => completer.future;

  @override
  String toString() {
    return 'txn $_id${completer.isCompleted ? ' completed' : ''}';
  }

  /// Make it an executor.
  SembastTransactionStore? toExecutor(SembastStore? store) =>
      store != null ? SembastTransactionStore(this, store) : null;

  /// Delete a store
  Future deleteStore(String storeName) =>
      database.txnDeleteStore(this, storeName);

  /// local helper
  SembastDatabase get database => sembastDatabase;

  @override
  Future<T> inTransaction<T>(
    FutureOr<T> Function(SembastTransaction transaction) action,
  ) async => action(this);

  @override
  SembastTransaction get sembastTransaction => this;

  @override
  SembastStore getSembastStore(StoreRef<Key?, Value?> ref) =>
      database.txnGetStore(this, ref.name)!.store;
}

/// Store implementation.
class SembastTransactionStore {
  /// Transaction.
  final SembastTransaction sembastTransaction;

  /// Store
  final SembastStore store;

  /// Constructor.
  SembastTransactionStore(this.sembastTransaction, this.store);

  @override
  String toString() {
    return '$store';
  }
}
