// basically same as the io runner but with extra output
import 'package:sembast/src/listener_content.dart';
import 'package:sembast/src/record_impl.dart';

import 'test_common.dart';

void main() {
  group('listener_content', () {
    test('add', () async {
      var store = StoreRef<int, String>.main();
      var dbContent = DatabaseListenerContent();
      dbContent.addRecord(ImmutableSembastRecord(store.record(1), 'v1'));
      var storeContent = dbContent.store(store);
      expect(storeContent.record(1).value, 'v1');

      dbContent.addRecord(ImmutableSembastRecord(store.record(1), 'v2'));
      expect(storeContent.record(1).value, 'v2');

      dbContent.removeStore(store);
      expect(dbContent.store(store), isNull);
    });
  });
}
