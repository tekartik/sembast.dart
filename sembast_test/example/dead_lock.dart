import 'dart:async';

import 'package:sembast/sembast_memory.dart';

Future<void> main(List<String> args) async {
  debugSembastWarnDatabaseCallInTransaction = true;
  var store = stringMapStoreFactory.store('store');
  var db = await openNewInMemoryDatabase();
  print('You should get a warning about a dead lock in about 10s');
  try {
    await db
        .transaction((txn) async {
          await store.add(db, {'test': 1});

          print('We should never get here');
        })
        .timeout(const Duration(seconds: 15));
  } on TimeoutException catch (_) {
    print('Timeout');
  }
}
