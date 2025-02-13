import 'package:sembast/src/record_snapshot_impl.dart';
import 'package:sembast/src/utils.dart';

import 'test_common.dart';

final storeFactory = intMapStoreFactory;
final otherStoreFactory = stringMapStoreFactory;
final StoreRef<int, Map<String, Object?>> testStore = storeFactory.store(
  'test',
);
final otherStore = StoreRef<String, Map<String, Object?>>('other');
final keyValueStore = StoreRef<String, String>('keyValue');

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  test('factory', () async {
    var record = storeFactory.store('test').record(1);
    var snapshot = SembastRecordSnapshot(record, <String, Object?>{'test': 1});
    expect(snapshot.ref.store.name, 'test');
    expect(snapshot.ref.key, 1);
    expect(snapshot.value, <String, Object?>{'test': 1});
  });

  test('read-only', () async {
    var record = storeFactory.store('test').record(1);
    var snapshot = SembastRecordSnapshot(
      record,
      ImmutableMap<String, Object?>(<String, Object?>{
        'test': {'sub': 1},
      }),
    );
    try {
      (snapshot['test'] as Map)['sub'] = 2;
      fail('should fail');
    } on StateError catch (_) {}

    expect(snapshot.value, <String, Object?>{
      'test': {'sub': 1},
    });
  });
}
