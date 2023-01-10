library sembast.test.value_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('value', () {
    late Database db;

    var store = StoreRef<int, Object>.main();
    var record = store.record(1);
    setUp(() async {
      db = await setupForTest(ctx, 'compat/value.db');
    });

    tearDown(() {
      return db.close();
    });

    test('int', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, 1234);
      Future checkRecord() async {
        final value = await record.get(db) as int?;
        expect(await record.exists(db), isTrue);
        expect(value, 1234);
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    test('double', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, 1234.5678);
      Future checkRecord() async {
        final value = await record.get(db) as double?;
        expect(await record.exists(db), isTrue);
        expect(value, closeTo(1234.5678, 0.0001));
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    test('bool', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, true);
      Future checkRecord() async {
        final value = await record.get(db) as bool?;
        expect(await record.exists(db), isTrue);
        expect(value, isTrue);
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    test('String', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, 'hello');
      Future checkRecord() async {
        final value = await record.get(db) as String?;
        expect(await record.exists(db), isTrue);
        expect(value, 'hello');
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    test('Timestamp', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, Timestamp(1, 2));
      Future checkRecord() async {
        final value = await record.get(db) as Timestamp?;
        expect(await record.exists(db), isTrue);
        expect(value, Timestamp(1, 2));
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
      await record.update(db, Timestamp(1, 3));
      expect(await record.get(db), Timestamp(1, 3));
      db = await reOpen(db);
      expect(await record.get(db), Timestamp(1, 3));
    });

    test('Blob', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, Blob.fromList([1, 2]));
      Future checkRecord() async {
        final value = await record.get(db) as Blob?;
        expect(await record.exists(db), isTrue);
        expect(value, Blob.fromList([1, 2]));
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    test('FieldValue.delete', () async {
      var store = StoreRef<Object, Object>.main();
      // Merge a non existing record
      expect(await record.exists(db), isFalse);
      await record.put(db, {'test': FieldValue.delete}, merge: true);
      Future checkRecord() async {
        final value = await record.get(db);
        expect(await record.exists(db), isTrue);
        expect(value, <String, Object>{});
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();

      try {
        await record.put(db, FieldValue.delete);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await record.add(db, FieldValue.delete);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await record.update(db, FieldValue.delete);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await record.put(db, {'test': FieldValue.delete});
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await record.add(db, {'test': FieldValue.delete});
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await store.add(db, FieldValue.delete);
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await store.add(db, {'test': FieldValue.delete});
        fail('should fail');
      } on ArgumentError catch (_) {}
      try {
        await store.update(db, FieldValue.delete);
        fail('should fail');
      } on ArgumentError catch (_) {}

      // Allowed!
      await record.update(db, {'test': FieldValue.delete});
      await store.update(db, {'test': FieldValue.delete});
    });

    test('Map', () async {
      final map = <String, Object?>{
        'int': 1234,
        'null': null,
        'double': 1234.5678,
        'String': 'hello',
        'nested': {'sub': 4321},
        'list': [
          {
            'nested': {'sub': 4321}
          }
        ]
      };
      expect(await record.exists(db), isFalse);
      await record.put(db, map);
      Future checkRecord() async {
        final value = await record.get(db) as Map<String, Object?>?;
        expect(await record.exists(db), isTrue);
        expect(value, map);
      }

      await checkRecord();
      db = await reOpen(db);
      await checkRecord();
    });

    /*
    test('immutable', () async {
      Map<String, Object?> map = {'int': 1234};
      var key = await record.put(db,map);
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.record(key).getSnapshot(db)).value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.records([key]).get(db)).first) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map = ((await store.records([key]).getSnapshots(db)).first.value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshots(db)).first.value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshot(db)).value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshot(db)).value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.findFirst(db)).value) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).update(db, {'int': 1234})) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map = (await store.record(key).put(db, {'int': 1234})).value
          as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, Object?>;
      expect(map, {'int': 1234});
      map = (await store.records([key]).put(db, [{'int': 1234}])
      )
          .first
          .value as Map<String, Object?>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, Object?>;
      expect(map, {'int': 1234});

      await db.transaction((txn) async {
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.record(key).getSnapshot(txn)).value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.records([key]).get(txn)).first) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map = ((await store.records([key]).getSnapshots(txn)).first.value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshots(txn)).first.value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshot(txn)).value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshot(txn)).value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.findFirst(txn)).value) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).update(txn, {'int': 1234})) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map = (await store.record(key).put(txn, {'int': 1234})).value
        as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, Object?>;
        expect(map, {'int': 1234});
        map = (await store.records([key]).put(txn, [{'int': 1234}])
        )
            .first
            .value as Map<String, Object?>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, Object?>;
        expect(map, {'int': 1234});
      });
    });

     */
  });
}
