// basically same as the io runner but with extra output
import 'package:sembast/sembast_memory.dart';

import 'test_common.dart';

void main() {
  var store = StoreRef<int, int>('test');
  var record = store.record(1);
  group('changes_listener', () {
    late Database db;
    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase('test.db');
    });
    tearDown(() async {});
    test('simple add', () async {
      var list = <RecordChange>[];
      void onChanges(Transaction txn, List<RecordChange> changes) {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.add(db, 2);
      expect(list.first.ref, record);
      expect(list.first.oldValue, null);
      expect(list.first.newValue, 2);
    });

    test('add/update/delete', () async {
      var list = <RecordChange>[];
      void onChanges(Transaction txn, List<RecordChange> changes) {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);

      await record.add(db, 1);
      expect(list.first.ref, record);
      expect(list.first.oldValue, null);
      expect(list.first.oldSnapshot, null);
      expect(list.first.newValue, 1);
      expect(list.first.newSnapshot!.value, 1);
      expect(list.first.isAdd, isTrue);
      expect(list.first.isDelete, isFalse);
      expect(list.first.isUpdate, isFalse);
      list.clear();
      await record.put(db, 2);
      expect(list.first.ref, record);
      expect(list.first.oldValue, 1);
      expect(list.first.oldSnapshot!.value, 1);
      expect(list.first.newValue, 2);
      expect(list.first.newSnapshot!.value, 2);
      expect(list.first.isAdd, isFalse);
      expect(list.first.isDelete, isFalse);
      expect(list.first.isUpdate, isTrue);
      list.clear();
      await record.delete(db);
      expect(list.first.ref, record);
      expect(list.first.oldValue, 2);
      expect(list.first.newValue, isNull);
      expect(list.first.isAdd, isFalse);
      expect(list.first.isDelete, isTrue);
      expect(list.first.isUpdate, isFalse);
    });
    test('add/remove listener/delete', () async {
      var list = <RecordChange>[];
      void onChanges(Transaction txn, List<RecordChange> changes) {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 1);
      await record.put(db, 2);
      expect(list.length, 2);
      store.removeOnChangesListener(db, onChanges);
      await record.put(db, 3);
      expect(list.length, 2);
    });
    test('cascade', () async {
      var list = <RecordChange>[];
      Future<void> onChanges(
          Transaction txn, List<RecordChange<int, int>> changes) async {
        for (var change in changes) {
          if (change.newValue! < 3) {
            // Update
            await change.ref.put(txn, change.newValue! + 1);
          }
        }
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 3);
    });
    test('deleteAll', () async {
      var list = <RecordChange>[];
      Future<void> onChanges(
          Transaction txn, List<RecordChange<int, int>> changes) async {
        list.addAll(changes);
      }

      store.addOnChangesListener(db, onChanges);
      await record.put(db, 1);
      expect(list.length, 1);
      await store.drop(db);
      expect(list.length, 2);
      await record.put(db, 1);
      expect(list.length, 3);
    });
  });
}
