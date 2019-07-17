import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/utils.dart';

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

  test('read-only', () async {
    var record = storeFactory.store('test').record(1);
    var snapshot = SembastRecordSnapshot(
        record,
        ImmutableMap(<String, dynamic>{
          'test': {'sub': 1}
        }));
    try {
      (snapshot['test'] as Map)['sub'] = 2;
      fail('should fail');
    } on StateError catch (_) {}

    expect(snapshot.value, <String, dynamic>{
      'test': {'sub': 1}
    });
  });
}
