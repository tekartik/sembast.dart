library sembast.test.src_ref_common_test;

import 'test_common.dart';

void main() {
  test('ref_common', () async {
    var store = StoreRef<int, String>.main();
    var record1 = store.record(1);
    var record2 = store.record(2);
    var records = store.records([1, 2]);
    expect(records.refs, [record1, record2]);
  });
}
