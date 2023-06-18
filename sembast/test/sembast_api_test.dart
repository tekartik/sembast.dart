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

      store.count;
      store.find;
      store.findFirst;
      // 2023-06-15 v3.4.8-1
      SembastRecordRefSyncExtension(record).getSync;
      SembastRecordRefSyncExtension(record).getSnapshotSync;
      SembastRecordRefSyncExtension(record).existsSync;

      SembastRecordsRefSyncExtension(records).getSync;
      SembastRecordsRefSyncExtension(records).getSnapshotsSync;
      SembastRecordsRefExtension(records).onSnapshots;

      SembastStoreRefCommonExtension(store).recordsFromRefs;
      SembastRecordsRefCommonExtension(records).refs;
      SembastRecordsRefCommonExtension(records).length;
      SembastRecordsRefCommonExtension(records)[0];

      valuesCompare;

      // 2023-06-18 v3.4.9-1
      SembastStoreRefSyncExtension(store).countSync;
      SembastStoreRefSyncExtension(store).findKeysSync;
      SembastStoreRefSyncExtension(store).findKeySync;
      SembastStoreRefSyncExtension(store).findSync;
      SembastStoreRefSyncExtension(store).findFirstSync;

      var query = store.query();

      SembastQueryRefExtension(query).count;
      SembastQueryRefExtension(query).onCount;

      SembastQueryRefSyncExtension(query).getSnapshotsSync;
      SembastQueryRefSyncExtension(query).getSnapshotSync;
      SembastStoreRefSyncExtension(store).findFirstSync;
    });
  });
}
