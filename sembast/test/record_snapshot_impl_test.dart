import 'package:sembast/sembast.dart';
import 'package:sembast/src/record_snapshot_impl.dart';

import 'test_common.dart';

final storeFactory = intMapStoreFactory;
final otherStoreFactory = stringMapStoreFactory;
final testStore = storeFactory.store('test');
final otherStore = StoreRef<String, Map<String, dynamic>>('other');
final keyValueStore = StoreRef<String, String>('keyValue');

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  test('factory', () async {
    var record = storeFactory.store('test').record(1);
    var snapshot = SembastRecordSnapshot(record, <String, dynamic>{'test': 1});
    expect(snapshot.ref.store.name, 'test');
    expect(snapshot.ref.key, 1);
    expect(snapshot.value, <String, dynamic>{'test': 1});
  });
}
