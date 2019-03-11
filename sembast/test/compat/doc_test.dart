library sembast.compat.doc_test;

import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'test_common.dart';
import 'xxtea_codec.dart';

void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryDatabaseContext);
}

void unused(dynamic value) {}

void defineTests(DatabaseTestContext ctx) {
  group('compat_doc', () {
    Database db;

    setUp(() async {});

    tearDown(() async {
      if (db != null) {
        await db.close();
        db = null;
      }
    });

    test('pre_1.15 doc', () async {
      db = await setupForTest(ctx);

      {
        // Cast necessary to manipulate the key
        var key = await db.put({'offline': true}) as int;
        Record record = await db.getRecord(key);
        // Cast necessary to manipulate the data
        var value = record.value as Map<String, dynamic>;

        unused(value);
      }
    });

    test('issue8_1', () async {
      db = await setupForTest(ctx);

      dynamic lastKey;
      var macAddress = '00:0a:95:9d:68:16';
      await db.transaction((txn) async {
        // put twice the same record
        await txn.put({'macAddress': macAddress});
        lastKey = await txn.put({'macAddress': macAddress});
      });
      // Sorting by key requires using the special Field.key
      var finder = Finder(
          filter: Filter.equal('macAddress', macAddress),
          sortOrders: [SortOrder(Field.key, false)]);
      // finding one record automatically set limit to 1
      expect((await db.findRecord(finder)).key, lastKey);
    });

    test('issue8_2', () async {
      db = await setupForTest(ctx);
      var beaconsStoreName = 'beacons';
      dynamic key2, key3;
      await db.transaction((txn) async {
        var store = txn.getStore(beaconsStoreName);
        await store.put({'name': 'beacon1'});
        key2 = await store.put({'name': 'beacon2'});
        key3 = await store.put({'name': 'beacon3'});
      });

      var recordsIds = [key2, key3];
      await db.transaction((txn) async {
        var store = txn.getStore(beaconsStoreName);
        List<Future> futures = [];
        recordsIds.forEach(
            (key) => futures.add(store.update({'flushed': true}, key)));
        await Future.wait(futures);
      });

      var store = db.getStore(beaconsStoreName);
      var records = await store.findRecords(null);
      expect(getRecordsValues(records), [
        {'name': 'beacon1'},
        {'name': 'beacon2', 'flushed': true},
        {'name': 'beacon3', 'flushed': true}
      ]);
    });
  });
}

void defineFileSystemTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    // print(dbPath);
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  group('compat_doc', () {
    test('codec_doc', () async {
      await prepareForDb();

      {
        // Initialize the encryption codec with a user password
        var codec = getXXTeaSembastCodec(password: '[your_user_password]');

        // Open the database with the codec
        Database db = await factory.openDatabase(dbPath, codec: codec);

        // ...your database is ready to use as encrypted

        // Put 4 records for having a simple output
        await db.put('test');
        await db.put('some longer record that will take more space');
        await db.put('short');
        await db.put('some very longer record that will take event more space');

        await db.close();
      }
    });
  });
}
