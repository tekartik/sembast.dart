import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

void main() {
  group('store_api', () {
    test('public', () {
      // What we want public
      // ignore: unnecessary_statements
      StoreRef;
      // ignore: unnecessary_statements
      RecordRef;
      // ignore: unnecessary_statements
      Database;
      // ignore: unnecessary_statements
      Transaction;
      // ignore: unnecessary_statements
      RecordSnapshot;
      // ignore: unnecessary_statements
      RecordsRef;
      // ignore: unnecessary_statements
      intMapStoreFactory;
      // ignore: unnecessary_statements
      stringMapStoreFactory;
      // ignore: unnecessary_statements
      SortOrder;
      // ignore: unnecessary_statements
      Finder;
      // ignore: unnecessary_statements
      Filter;
      // ignore: unnecessary_statements
      Boundary;
      // ignore: unnecessary_statements
      SembastCodec;
      // ignore: unnecessary_statements
      QueryRef;
      // ignore: unnecessary_statements
      FieldValue;
      // ignore: unnecessary_statements
      FieldKey;
      // ignore: unnecessary_statements
      Field;
      // ignore: unnecessary_statements
      sembastDefaultTypeAdapters;
      // ignore: unnecessary_statements
      sembastCodecDefault;
      // ignore: unnecessary_statements
      sembastCodecWithAdapters;

      // ignore: unnecessary_statements
      var store = StoreRef.main();

      // ignore: unnecessary_statements
      store.query;

      var record = store.record(1);
      // ignore: unnecessary_statements
      record.get;
    });

    test('null_store', () {
      try {
        StoreRef(null);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });

    test('key', () {
      var store = StoreRef.main();
      try {
        store.record(null);
        fail('should fail');
      } on ArgumentError catch (_) {}
    });
  });
}
