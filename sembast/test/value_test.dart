library sembast.test.value_test;

// basically same as the io runner but with extra output
import 'dart:async';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('value', () {
    Database db;

    var store = StoreRef.main();
    var record = store.record(1);
    setUp(() async {
      db = await setupForTest(ctx, 'compat/value.db');
    });

    tearDown(() {
      return db.close();
    });

    test('null', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, null);

      Future _check() async {
        expect(await record.exists(db), isTrue);
        expect(await record.get(db), isNull);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('int', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, 1234);
      Future _check() async {
        final value = await record.get(db) as int;
        expect(await record.exists(db), isTrue);
        expect(value, 1234);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('double', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, 1234.5678);
      Future _check() async {
        final value = await record.get(db) as double;
        expect(await record.exists(db), isTrue);
        expect(value, closeTo(1234.5678, 0.0001));
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('bool', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, true);
      Future _check() async {
        final value = await record.get(db) as bool;
        expect(await record.exists(db), isTrue);
        expect(value, isTrue);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('String', () async {
      expect(await record.exists(db), isFalse);
      await record.put(db, "hello");
      Future _check() async {
        final value = await record.get(db) as String;
        expect(await record.exists(db), isTrue);
        expect(value, "hello");
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('Map', () async {
      Map<String, dynamic> map = {
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
      Future _check() async {
        final value = await record.get(db) as Map<String, dynamic>;
        expect(await record.exists(db), isTrue);
        expect(value, map);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    /*
    test('immutable', () async {
      Map<String, dynamic> map = {'int': 1234};
      var key = await record.put(db,map);
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.record(key).getSnapshot(db)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.records([key]).get(db)).first) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map = ((await store.records([key]).getSnapshots(db)).first.value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshots(db)).first.value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshot(db)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.query().getSnapshot(db)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await store.findFirst(db)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).update(db, {'int': 1234})) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map = (await store.record(key).put(db, {'int': 1234})).value
          as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map = (await store.records([key]).put(db, [{'int': 1234}])
      )
          .first
          .value as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await store.record(key).get(db)) as Map<String, dynamic>;
      expect(map, {'int': 1234});

      await db.transaction((txn) async {
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.record(key).getSnapshot(txn)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.records([key]).get(txn)).first) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map = ((await store.records([key]).getSnapshots(txn)).first.value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshots(txn)).first.value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshot(txn)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.query().getSnapshot(txn)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await store.findFirst(txn)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).update(txn, {'int': 1234})) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map = (await store.record(key).put(txn, {'int': 1234})).value
        as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map = (await store.records([key]).put(txn, [{'int': 1234}])
        )
            .first
            .value as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await store.record(key).get(txn)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
      });
    });

     */
  });
}
