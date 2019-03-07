import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_store.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/store_impl.dart';

mixin StoreExecutorMixin implements StoreExecutor {
  Future<T> inTransaction<T>(FutureOr<T> action(Transaction transaction));
  SembastDatabase get sembastDatabase;
  SembastStore get sembastStore;
}

StoreExecutorMixin storeExecutorMixin(DatabaseClient client) {
  var storeExecutorMixin = client as StoreExecutorMixin;
  // Force
  forceReadImmutable(storeExecutorMixin);

  return storeExecutorMixin;
}
