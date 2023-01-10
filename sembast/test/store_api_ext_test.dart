import 'package:sembast/sembast.dart' show Filter, RecordRef, StoreRef;
import 'package:sembast/sembast.dart'
    show
        SembastStoreRefExtension,
        SembastRecordRefExtension,
        SembastFilterCombination;
import 'package:test/test.dart';

void main() {
  group('store_api', () {
    test('store', () {
      // What we want public
      // ignore: unnecessary_statements
      StoreRef;

      // ignore: unnecessary_statements
      var store = StoreRef<int, String>.main();

      // ignore: unnecessary_statements
      store.query;
      // ignore: unnecessary_statements
      store.find;
    });
    test('record', () {
      // ignore: unnecessary_statements
      RecordRef;
      // ignore: unnecessary_statements
      var store = StoreRef<int, String>.main();

      var record = store.record(1);
      // ignore: unnecessary_statements
      record.get;

      // ignore: unnecessary_statements
      record.onSnapshot;
    });
    test('filter', () {
      var filter = Filter.custom((record) => false);
      // ignore: unnecessary_statements
      SembastFilterCombination(filter) | filter;
      // ignore: unnecessary_statements
      SembastFilterCombination(filter) & filter;
    });
  });
}
