// ignore_for_file: unnecessary_statements

import 'package:sembast/sembast.dart';
import 'package:sembast/utils/value_utils.dart';
import 'package:test/test.dart';

var store = StoreRef<int, String>.main();
var record = store.record(1);
var records = store.records([1, 2]);

void main() {
  group('sembast_api', () {
    test('public', () async {
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
      SembastRecordRefExtension(record).get;
      SembastRecordRefExtension(record).onSnapshot;
      // 2023-06-15 v3.4.8-1
      SembastRecordRefSyncExtension(record).getSync;
      SembastRecordRefSyncExtension(record).getSnapshotSync;
      SembastRecordRefSyncExtension(record).existsSync;
      SembastRecordRefSyncExtension(record).onSnapshotSync;

      SembastRecordsRefExtension(records).onSnapshots;
      SembastStoreRefCommonExtension(store).recordsFromRefs;

      SembastRecordsRefSyncExtension(records).getSync;
      SembastRecordsRefSyncExtension(records).getSnapshotsSync;
      SembastRecordsRefSyncExtension(records).onSnapshotsSync;

      SembastRecordsRefCommonExtension(records).refs;
      SembastRecordsRefCommonExtension(records).length;
      SembastRecordsRefCommonExtension(records)[0];

      valuesCompare;

      SembastStoreRefExtension(store).onCount;

      // 2023-06-18 v3.4.9-1
      SembastStoreRefSyncExtension(store).countSync;
      SembastStoreRefSyncExtension(store).findKeysSync;
      SembastStoreRefSyncExtension(store).findKeySync;
      SembastStoreRefSyncExtension(store).findSync;
      SembastStoreRefSyncExtension(store).findFirstSync;

      var query = store.query();

      SembastQueryRefExtension(query).count;
      SembastQueryRefExtension(query).onCount;
      SembastQueryRefExtension(query).onSnapshot;
      SembastQueryRefExtension(query).onSnapshots;

      SembastQueryRefSyncExtension(query).getSnapshotsSync;
      SembastQueryRefSyncExtension(query).getSnapshotSync;
      SembastQueryRefSyncExtension(query).countSync;
      SembastQueryRefSyncExtension(query).onSnapshotsSync;
      SembastQueryRefSyncExtension(query).onSnapshotSync;
      SembastQueryRefSyncExtension(query).onCountSync;

      // ignore: unused_element
      Future<void> ignored(Database db) async {
        await DatabaseExtension(db).reload();
        await DatabaseExtension(db).reOpen();
        await DatabaseExtension(db).checkForChanges();
        await DatabaseExtension(db).compact();
      }

      // ignore: unused_element
      void ignoreSnapshots(List<RecordSnapshot> snapshots) {
        RecordSnapshotIterableExtension(snapshots).keys;
        RecordSnapshotIterableExtension(snapshots).values;
        RecordSnapshotIterableExtension(snapshots).keysAndValues;
      }
    });
  });
}
