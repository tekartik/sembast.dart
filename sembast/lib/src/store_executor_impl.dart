import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/record_impl.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

mixin StoreExecutorMixin implements StoreExecutor {
  Future<T> inTransaction<T>(FutureOr<T> action(Transaction transaction));
  SembastDatabase get sembastDatabase;
  SembastTransaction get sembastTransaction;

  SembastStore getSembastStore(StoreRef ref) {
    return sembastDatabase.getSembastStore(ref);
  }

  Future<ImmutableSembastRecord> getImmutableRecord<K, V>(RecordRef<K, V> ref) {
    return getSembastStore(ref.store).txnGetRecord(sembastTransaction, ref.key);
  }

  Future<List<ImmutableSembastRecord>> getImmutableRecords<K, V>(
      StoreRef<K, V> store, Iterable<K> keys) {
    return getSembastStore(store).txnGetRecords(sembastTransaction, keys);
  }

  Future<ImmutableSembastRecord> findImmutableRecord<K, V>(
      StoreRef<K, V> store, Finder finder) {
    return getSembastStore(store).txnFindRecord(sembastTransaction, finder);
  }

  Future<List<ImmutableSembastRecord>> findImmutableRecords<K, V>(
      StoreRef<K, V> store, Finder finder) {
    return getSembastStore(store).txnFindRecords(sembastTransaction, finder);
  }
}

StoreExecutorMixin storeExecutorMixin(DatabaseClient client) {
  var storeExecutorMixin = client as StoreExecutorMixin;
  // Force
  forceReadImmutable(storeExecutorMixin);

  return storeExecutorMixin;
}
