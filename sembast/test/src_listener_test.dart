// basically same as the io runner but with extra output
import 'package:sembast/src/listener.dart';
import 'package:sembast/src/store_ref_impl.dart';

import 'test_common.dart';

void main() {
  group('listener', () {
    test('Record.onSnapshot', () async {
      var store = StoreRef<int, String>.main();

      var dbListener = DatabaseListener();
      var ctlr = dbListener.addRecord(store.record(1), onListen: null);
      expect(dbListener.isNotEmpty, isTrue);
      var storeListener = dbListener.getStore(store)!;
      expect(storeListener.keyHasRecordListener(1), isTrue);
      expect(storeListener.hasQueryListener, isFalse);
      expect(storeListener.keyHasAnyListener(1), isTrue);
      expect(dbListener.recordHasAnyListener(store.record(1)), isTrue);

      var queryCtrl = dbListener.addQuery(store.query(), onListen: null);
      expect(storeListener.hasQueryListener, isTrue);

      dbListener.removeRecord(ctlr);
      expect(storeListener.keyHasRecordListener(1), isFalse);
      expect(storeListener.hasQueryListener, isTrue);
      expect(storeListener.keyHasAnyListener(1), isTrue);
      expect(dbListener.recordHasAnyListener(store.record(1)), isTrue);

      dbListener.removeQuery(queryCtrl);
      expect(dbListener.isEmpty, isTrue);
      expect(dbListener.recordHasAnyListener(store.record(1)), isFalse);

      expect(dbListener.getStore(store), isNull);
      var countCtrl = dbListener.addCount(store.filter(), onListen: null);
      storeListener = dbListener.getStore(store)!;
      expect(storeListener.hasQueryListener, isTrue);
      dbListener.removeQuery(countCtrl);
      expect(storeListener.hasQueryListener, isFalse);
      expect(dbListener.getStore(store), isNull);
    });
  });
}
