library sembast.value_test;

// basically same as the io runner but with extra output
import 'dart:async';
import 'package:sembast/sembast.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  group('value', () {
    Database db;

    setUp(() async {
      db = await setupForTest(ctx);
    });

    tearDown(() {
      return db.close();
    });

    test('null', () async {
      expect(await db.containsKey(1), isFalse);
      await db.put(null);

      Future _check() async {
        expect(await db.containsKey(1), isTrue);
        expect(await db.get(1), isNull);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('int', () async {
      expect(await db.containsKey(1), isFalse);
      await db.put(1234);
      Future _check() async {
        final value = await db.get(1) as int;
        expect(await db.containsKey(1), isTrue);
        expect(value, 1234);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('double', () async {
      expect(await db.containsKey(1), isFalse);
      await db.put(1234.5678);
      Future _check() async {
        final value = await db.get(1) as double;
        expect(await db.containsKey(1), isTrue);
        expect(value, closeTo(1234.5678, 0.0001));
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('bool', () async {
      expect(await db.containsKey(1), isFalse);
      await db.put(true);
      Future _check() async {
        final value = await db.get(1) as bool;
        expect(await db.containsKey(1), isTrue);
        expect(value, isTrue);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('String', () async {
      expect(await db.containsKey(1), isFalse);
      await db.put("hello");
      Future _check() async {
        final value = await db.get(1) as String;
        expect(await db.containsKey(1), isTrue);
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
      expect(await db.containsKey(1), isFalse);
      await db.put(map);
      Future _check() async {
        final value = await db.get(1) as Map<String, dynamic>;
        expect(await db.containsKey(1), isTrue);
        expect(value, map);
      }

      await _check();
      db = await reOpen(db);
      await _check();
    });

    test('immutable', () async {
      Map<String, dynamic> map = {'int': 1234};
      var key = await db.put(map);
      map['int'] = 5678;
      map = (await db.get(key)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.getRecord(key)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.getRecords([key])).first.value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.findRecords(null)).first.value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.findRecord(null)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.findRecord(null)).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = ((await db.records.first).value) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await db.update({'int': 1234}, key)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await db.get(key)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map = (await db.putRecord(Record(null, {'int': 1234}, key))).value
          as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await db.get(key)) as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map = (await db.putRecords([
        Record(null, {'int': 1234}, key)
      ]))
          .first
          .value as Map<String, dynamic>;
      expect(map, {'int': 1234});
      map['int'] = 5678;
      map = (await db.get(key)) as Map<String, dynamic>;
      expect(map, {'int': 1234});

      await db.transaction((txn) async {
        map['int'] = 5678;
        map = (await txn.get(key)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await txn.getRecord(key)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map =
            ((await txn.getRecords([key])).first.value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map =
            ((await txn.findRecords(null)).first.value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await txn.findRecord(null)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await txn.findRecord(null)).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = ((await txn.records.first).value) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await txn.update({'int': 1234}, key)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await txn.get(key)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map = (await txn.putRecord(Record(null, {'int': 1234}, key))).value
            as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await txn.get(key)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map = (await txn.putRecords([
          Record(null, {'int': 1234}, key)
        ]))
            .first
            .value as Map<String, dynamic>;
        expect(map, {'int': 1234});
        map['int'] = 5678;
        map = (await txn.get(key)) as Map<String, dynamic>;
        expect(map, {'int': 1234});
      });
    });
  });
}
