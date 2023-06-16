// ignore_for_file: unnecessary_statements

import 'package:sembast/sembast.dart';
import 'package:sembast/utils/value_utils.dart';
import 'package:test/test.dart';

var store = StoreRef<int, String>.main();
var record = store.record(1);
var records = store.records([1, 2]);

void main() {
  group('sembast_api', () {
    test('public', () {
      // What we want public
      StoreRef;
      RecordRef;
      Database;
      Transaction;
      RecordSnapshot;
      RecordsRef;
      intMapStoreFactory;
      stringMapStoreFactory;
      SortOrder;
      Finder;
      Filter;
      Boundary;
      SembastCodec;
      QueryRef;
      FieldValue;
      FieldKey;
      Field;
      sembastDefaultTypeAdapters;
      sembastCodecDefault;
      sembastCodecWithAdapters;
      AsyncContentCodecBase;
      RecordKeyBase;
      RecordValueBase;

      var store = StoreRef<int, String>.main();
      store.query;
      record.get;

      // 2023-06-15 v3.4.8-1
      SembastRecordRefExtension(record).getSync;
      SembastRecordRefExtension(record).getSnapshotSync;
      SembastRecordRefExtension(record).existsSync;

      SembastRecordsRefExtension(records).getSync;
      SembastRecordsRefExtension(records).getSnapshotsSync;
      SembastRecordsRefExtension(records).onSnapshots;

      SembastStoreRefCommonExtension(store).recordsFromRefs;
      SembastRecordsRefCommonExtension(records).refs;
      SembastRecordsRefCommonExtension(records).length;
      SembastRecordsRefCommonExtension(records)[0];

      valuesCompare;
    });
  });
}
