// Regression tests of the 2026-11-09 review (level 1).
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/file_system.dart' show FileMode;
import 'package:sembast/src/jdb/database_factory_jdb.dart';
import 'package:sembast/src/jdb/jdb_factory_memory.dart';
import 'package:sembast/src/memory/database_factory_memory.dart';
import 'package:sembast/src/memory/file_system_memory.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/stream_utils.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';

import 'test_common.dart';

/// Write [lines] to a file of the memory file system.
Future<void> _writeMemoryFile(String path, List<String> lines) async {
  await fileSystemMemory.directory(p.dirname(path)).create(recursive: true);
  var sink = fileSystemMemory.file(path).openWrite(mode: FileMode.write);
  for (var line in lines) {
    sink.writeln(line);
  }
  await sink.close();
}

const _metaLine = '{"version":1,"sembast":1}';

void main() {
  var mapStore = intMapStoreFactory.store('test');
  var store = StoreRef<int, String>('test');
  group('review_regression', () {
    group('memory', () {
      late Database db;
      setUp(() async {
        db = await newDatabaseFactoryMemory().openDatabase('review.db');
        await mapStore.record(1).put(db, {'a': 1});
        await mapStore.record(2).put(db, {'a': 2});
        await mapStore.record(3).put(db, {'a': 3});
      });
      tearDown(() async {
        await db.close();
      });

      test('findFirst, limit and offset in a transaction', () async {
        await db.transaction((txn) async {
          // Changed in the transaction, visited first
          await mapStore.record(3).put(txn, {'a': 30});
          expect((await mapStore.findFirst(txn))!.key, 1);
          expect(mapStore.findFirstSync(txn)!.key, 1);
          expect(await mapStore.findKeys(txn, finder: Finder(limit: 2)), [
            1,
            2,
          ]);
          expect(mapStore.findKeysSync(txn, finder: Finder(limit: 2)), [1, 2]);
          expect(await mapStore.findKeys(txn, finder: Finder(offset: 1)), [
            2,
            3,
          ]);
          expect(
            await mapStore.findKeys(txn, finder: Finder(offset: 1, limit: 1)),
            [2],
          );
        });
      });

      test('limit 0 without sort order', () async {
        expect(await mapStore.find(db, finder: Finder(limit: 0)), isEmpty);
        expect(mapStore.findSync(db, finder: Finder(limit: 0)), isEmpty);
        expect(
          await mapStore.find(db, finder: Finder(limit: 0, offset: 1)),
          isEmpty,
        );
        await db.transaction((txn) async {
          await mapStore.record(3).put(txn, {'a': 30});
          expect(await mapStore.find(txn, finder: Finder(limit: 0)), isEmpty);
        });
      });

      test('store delete count in a transaction', () async {
        await db.transaction((txn) async {
          await mapStore.record(2).delete(txn);
          await mapStore.record(4).put(txn, {'a': 4});
          await mapStore.record(1).put(txn, {'a': 10});
          // 1, 3 and 4
          expect(await mapStore.delete(txn), 3);
        });
        expect(await mapStore.count(db), 0);
      });

      test('record deleted twice in a transaction', () async {
        await db.transaction((txn) async {
          expect(await mapStore.record(1).delete(txn), 1);
          expect(await mapStore.record(1).delete(txn), isNull);
        });
        expect(await mapStore.record(1).exists(db), isFalse);
      });

      test('record deleted twice with a changes listener', () async {
        var changes = <RecordChange<int, Map<String, Object?>>>[];
        void onChanges(
          Transaction txn,
          List<RecordChange<int, Map<String, Object?>>> list,
        ) {
          changes.addAll(list);
        }

        mapStore.addOnChangesListener(db, onChanges);
        await db.transaction((txn) async {
          await mapStore.record(1).delete(txn);
          await mapStore.record(1).delete(txn);
        });
        expect(changes, hasLength(1));
        expect(changes.first.isDelete, isTrue);
        expect(changes.first.oldValue, {'a': 1});
        mapStore.removeOnChangesListener(db, onChanges);
      });

      test('update and put merge do not reference the input', () async {
        var sub = <String, Object?>{'x': 1};
        var list = <Object?>[1];
        await mapStore.record(1).update(db, {'sub': sub, 'list': list});
        sub['x'] = 2;
        list.add(2);
        expect(await mapStore.record(1).get(db), {
          'a': 1,
          'sub': {'x': 1},
          'list': [1],
        });

        var sub2 = <String, Object?>{'y': 1};
        await mapStore.record(2).put(db, {'sub': sub2}, merge: true);
        sub2['y'] = 2;
        expect(await mapStore.record(2).get(db), {
          'a': 2,
          'sub': {'y': 1},
        });

        // Updating multiple records
        var sub3 = <String, Object?>{'z': 1};
        await mapStore.update(db, {'sub': sub3});
        sub3['z'] = 2;
        for (var key in [1, 2, 3]) {
          expect((await mapStore.record(key).get(db))!['sub'], {'z': 1});
        }
      });

      test('remove a typed changes listener', () async {
        var count = 0;
        void onChanges(
          Transaction txn,
          List<RecordChange<int, Map<String, Object?>>> changes,
        ) {
          count++;
        }

        mapStore.addOnChangesListener(db, onChanges);
        await mapStore.record(1).put(db, {'a': 11});
        mapStore.removeOnChangesListener(db, onChanges);
        await mapStore.record(1).put(db, {'a': 12});
        expect(count, 1);
      });

      test('changes listener removing itself', () async {
        var count = 0;
        var otherCount = 0;
        late void Function(
          Transaction txn,
          List<RecordChange<int, Map<String, Object?>>> changes,
        )
        onChanges;
        onChanges = (txn, changes) {
          count++;
          mapStore.removeOnChangesListener(db, onChanges);
        };
        void onOtherChanges(
          Transaction txn,
          List<RecordChange<int, Map<String, Object?>>> changes,
        ) {
          otherCount++;
        }

        mapStore.addOnChangesListener(db, onChanges);
        mapStore.addOnChangesListener(db, onOtherChanges);
        await mapStore.record(1).put(db, {'a': 11});
        await mapStore.record(1).put(db, {'a': 12});
        expect(count, 1);
        expect(otherCount, 2);
        mapStore.removeOnChangesListener(db, onOtherChanges);
      });

      test('global changes listener removing itself', () async {
        var count = 0;
        late TransactionRecordChangeListener onChanges;
        onChanges = (txn, changes) {
          count++;
          db.removeAllStoresOnChangesListener(onChanges);
        };
        db.addAllStoresOnChangesListener(onChanges);
        await mapStore.record(1).put(db, {'a': 11});
        await mapStore.record(1).put(db, {'a': 12});
        expect(count, 1);
      });

      test('map equality with other keys', () async {
        await mapStore.record(1).put(db, {
          'm': {'b': null},
        });
        expect(
          await mapStore.findKeys(
            db,
            finder: Finder(filter: Filter.equals('m', {'a': null})),
          ),
          isEmpty,
        );
        expect(
          await mapStore.findKeys(
            db,
            finder: Finder(filter: Filter.equals('m', {'b': null})),
          ),
          [1],
        );
      });
    });

    test('databaseMerge map with other keys', () async {
      var factory = newDatabaseFactoryMemory();
      var src = await factory.openDatabase('src.db');
      var dst = await factory.openDatabase('dst.db');
      await mapStore.record(1).put(src, {'b': null});
      await mapStore.record(1).put(dst, {'a': null});
      await databaseMerge(dst, sourceDatabase: src);
      expect(await mapStore.record(1).get(dst), {'b': null});
      await src.close();
      await dst.close();
    });

    test('import of an invalid export keeps the destination', () async {
      var factory = newDatabaseFactoryMemory();
      var db = await factory.openDatabase('import_dst.db');
      await mapStore.record(1).put(db, {'a': 1});
      await db.close();
      await expectLater(
        () => importDatabase({'sembast_export': 2}, factory, 'import_dst.db'),
        throwsA(isA<FormatException>()),
      );
      db = await factory.openDatabase('import_dst.db');
      expect(await mapStore.record(1).get(db), {'a': 1});
      await db.close();
    });

    test('neverFails skips the json lines that are not maps', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/not_map.db';
      await _writeMemoryFile(path, [
        _metaLine,
        '{"key":1,"store":"test","value":"a"}',
        '[1]',
        'null',
        '1',
        '{"key":2,"store":"test","value":"b"}',
      ]);
      var db = await factory.openDatabase(path);
      expect(await store.findKeys(db), [1, 2]);
      await db.close();
    });

    test('neverFails first line not a map', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/first_not_map.db';
      await _writeMemoryFile(path, ['[1]', '{"key":1,"value":"a"}']);
      var db = await factory.openDatabase(path);
      expect(await store.count(db), 0);
      await db.close();
    });

    test('checkForChanges full import restarts the listeners', () async {
      var jdb = JdbFactoryMemory();
      var db1 = await DatabaseFactoryJdb(jdb).openDatabase('check.db');
      var db2 = await DatabaseFactoryJdb(jdb).openDatabase('check.db');
      var events = <List<int>>[];
      var subscription = store.query().onKeys(db2).listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, [<int>[]]);
      await store.record(1).put(db1, 'a');
      await store.record(1).delete(db1);
      await store.record(3).put(db1, 'c');
      // Delta import no longer possible for db2
      await db1.compact();
      await db2.checkForChanges();
      expect(await store.findKeys(db2), [3]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events.last, [3]);
      await subscription.cancel();
      await db1.close();
      await db2.close();
    });

    test(
      'upgrade retried after a concurrent write saves the version',
      () async {
        var jdb = JdbFactoryMemory();
        var db1 = await DatabaseFactoryJdb(
          jdb,
        ).openDatabase('upgrade.db', version: 1);
        var calls = 0;
        var db2 = await DatabaseFactoryJdb(jdb).openDatabase(
          'upgrade.db',
          version: 2,
          onVersionChanged: (db, oldVersion, newVersion) async {
            calls++;
            if (calls == 1) {
              // Another instance writes during the upgrade
              await store.record(10).put(db1, 'other');
            }
            await store.record(1).put(db, 'v$newVersion');
          },
        );
        // Retried once
        expect(calls, 2);
        expect(db2.version, 2);
        await db2.close();
        await db1.close();
        var upgrades = <String>[];
        var db3 = await DatabaseFactoryJdb(jdb).openDatabase(
          'upgrade.db',
          version: 2,
          onVersionChanged: (db, oldVersion, newVersion) {
            upgrades.add('$oldVersion->$newVersion');
          },
        );
        expect(upgrades, isEmpty);
        expect(await store.record(1).get(db3), 'v2');
        await db3.close();
      },
    );

    test('second close after a reopen keeps a single instance', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/double_close.db';
      await factory.deleteDatabase(path);
      var db1 = await factory.openDatabase(path);
      await db1.close();
      var db2 = await factory.openDatabase(path);
      // Closing an already closed database again
      await db1.close();
      var db3 = await factory.openDatabase(path);
      expect(identical(db2, db3), isTrue);
      await db2.close();
    });

    test('two opens waiting for a close get the same instance', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/concurrent_open.db';
      await factory.deleteDatabase(path);
      var db1 = await factory.openDatabase(path);
      var closeFuture = db1.close();
      var dbs = await Future.wait([
        factory.openDatabase(path),
        factory.openDatabase(path),
      ]);
      await closeFuture;
      expect(identical(dbs[0], dbs[1]), isTrue);
      await dbs[0].close();
    });

    /// The file a compaction that failed leaves.
    Future<void> writeLeftoverTmp(String path) async {
      await _writeMemoryFile(
        FsDatabaseStorage(fileSystemMemory, path).tmpPath,
        [_metaLine, '{"key":1,"store":"test","value":"old"}'],
      );
    }

    test('deleteDatabase deletes a leftover compaction file', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/tmp_delete/t.db';
      var db = await factory.openDatabase(path);
      await store.record(1).put(db, 'current');
      await db.close();
      await writeLeftoverTmp(path);
      await factory.deleteDatabase(path);
      db = await factory.openDatabase(path);
      expect(await store.record(1).get(db), isNull);
      await db.close();
    });

    test('mode empty deletes a leftover compaction file', () async {
      var factory = DatabaseFactoryMemoryFs();
      var path = 'review_regression/tmp_empty/t.db';
      var db = await factory.openDatabase(path);
      await store.record(1).put(db, 'current');
      await db.close();
      await writeLeftoverTmp(path);
      db = await factory.openDatabase(path, mode: DatabaseMode.empty);
      expect(await store.record(1).get(db), isNull);
      await db.close();
    });

    test('memory factory mode empty', () async {
      var factory = newDatabaseFactoryMemory();
      var db = await factory.openDatabase('empty.db');
      await store.record(1).put(db, 'a');
      await db.close();
      db = await factory.openDatabase('empty.db', mode: DatabaseMode.empty);
      expect(await store.record(1).get(db), isNull);
      await db.close();
    });

    test('streamJoinAll forwards errors', () async {
      var controller = StreamController<int>();
      var errors = <Object>[];
      var subscription = streamJoinAll([
        controller.stream,
      ]).listen((_) {}, onError: errors.add);
      controller.addError('boom');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(errors, ['boom']);
      await subscription.cancel();
      await controller.close();
    });
  });
}
