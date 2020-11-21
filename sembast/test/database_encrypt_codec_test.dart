// @dart=2.9
@TestOn('vm')
library sembast.test.database_codec_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'database_format_test.dart' as database_format_test;
import 'encrypt_codec.dart';
import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  // String getDbPath() => ctx.outPath + '.db';
  String dbPath;
  var store = StoreRef<int, dynamic>.main();

  Future<String> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_codec.db');
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  Future<Database> _prepareOneRecordDatabase({SembastCodec codec}) async {
    await prepareForDb();
    var db = await factory.openDatabase(dbPath, codec: codec);
    await store.add(db, 'test');
    return db;
  }

  group('database encrypt_codec', () {
    var codec = getEncryptSembastCodec(password: 'user_password');
    database_format_test.defineTestsWithCodec(ctx, codec: codec);
    //_commonTests(codec);

    test('read existing', () async {
      dbPath =
          dbPathFromName('compat/database_code/encrypt_codec/read_existing.db');
      await writeContent(fs, dbPath, [
        '{"version":1,"sembast":1,"codec":"i6/eGhL+yC4=gYCjWHqkgdawwoROer5+jQ0EzCdgFrk="}',
        'GY9lA8yc56M=FSqctQswKkhfgzp/XaFdxOxSJhRGHB3a'
      ]);
      var db = await factory.openDatabase(dbPath, codec: codec);
      expect(await store.record(1).get(db), 'test');
      await db.close();
    });
    test('one_record', () async {
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();
      final lines = await readContent(fs, dbPath);
      // print(lines);
      expect(lines.length, 2);
      expect(codec.codec?.decode(json.decode(lines.first)['codec'] as String),
          {'signature': 'encrypt'});
      expect(codec.codec?.decode(lines[1]), {'key': 1, 'value': 'test'});
    });

    test('reopen_and_compact', () async {
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await store.record(1).get(db), 'test');

      await (db as SembastDatabase).compact();

      final lines = await readContent(fs, dbPath);
      expect(lines.length, 2);
      expect((json.decode(lines.first) as Map)..remove('codec'), {
        'version': 1,
        'sembast': 1,
      });
      expect(codec.codec?.decode(json.decode(lines.first)['codec'] as String),
          {'signature': 'encrypt'});

      expect(codec.codec?.decode(lines[1]), {'key': 1, 'value': 'test'});

      await db.close();
    });

    test('open with wrong password', () async {
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      try {
        var codecWithABadPassword =
            getEncryptSembastCodec(password: 'bad_password');
        // Open again with a bad password
        db = await factory.openDatabase(dbPath, codec: codecWithABadPassword);

        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }

      // Open again with the proper password
      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await store.record(1).get(db), 'test');
      await db.close();
    });
  });

  test('invalid_codec', () async {
    try {
      await _prepareOneRecordDatabase(
          codec: SembastCodec(signature: 'test', codec: null));
      fail('should fail');
    } on DatabaseException catch (e) {
      expect(e.code, DatabaseException.errInvalidCodec);
    }
    try {
      await _prepareOneRecordDatabase(
          codec: SembastCodec(signature: null, codec: MyJsonCodec()));
      fail('should fail');
    } on DatabaseException catch (e) {
      expect(e.code, DatabaseException.errInvalidCodec);
    }
  });
}
