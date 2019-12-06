library sembast.compat.doc_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/sembast_fs.dart';

import '../encrypt_codec.dart';
import 'test_common.dart';

void main() {
  defineFileSystemTests(memoryFileSystemContext);
  defineTests(memoryDatabaseContext);
}

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
      db = await setupForTest(ctx, 'compat/doc/pre_1.15.db');

      {
        // Cast necessary to manipulate the key
        var key = await db.put({'offline': true}) as int;
        final record = await db.getRecord(key);
        // Cast necessary to manipulate the data
        var value = record.value as Map<String, dynamic>;

        unused(value);
      }
    });
  });
}

void defineFileSystemTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = dbPathFromName('compat/doc_fs.db');
    // print(dbPath);
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  group('compat_doc', () {
    test('codec_doc', () async {
      await prepareForDb();

      {
        // Initialize the encryption codec with a user password
        var codec = getEncryptSembastCodec(password: '[your_user_password]');

        // Open the database with the codec
        final db = await factory.openDatabase(dbPath, codec: codec);

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
