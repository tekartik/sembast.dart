import 'package:sembast/sembast.dart' show StoreRef;
import 'package:sembast/sembast.dart'
    show SembastStoreRefExtension, SembastRecordRefExtension;
import 'package:test/test.dart';

void main() {
  group('store_api', () {
    test('public', () {
      // What we want public
      // ignore: unnecessary_statements
      StoreRef;

      // ignore: unnecessary_statements
      var store = StoreRef.main();

      // ignore: unnecessary_statements
      store.query;
      // ignore: unnecessary_statements
      store.find;

      var record = store.record(1);
      // ignore: unnecessary_statements
      record.get;

      // ignore: unnecessary_statements
      record.onSnapshot;
    });
  });
}
