import 'package:sembast/sembast.dart';

/// Counter simple test
const commandVarSet = 'varSet';
// key: value: integer
/// Counter simple test
const commandVarGet = 'varGet';

const databasePath = 'web_worker_exp_test.db';
const storeKey = 'value';

var store = StoreRef<String, int>('values');

extension SharedWorkerExp on Database {
  /// Get a value from the store
  Future<int?> getValue(String key) async {
    return await store.record(key).get(this);
  }

  /// Set a value in the store
  Future<void> setValue(String key, int? value) async {
    if (value != null) {
      await store.record(key).put(this, value);
    } else {
      await store.record(key).delete(this);
    }
  }

  Future<int?> getTestValue() async {
    return await getValue(storeKey);
  }

  Future<void> setTestValue(int? value) async {
    await setValue(storeKey, value);
  }
}
