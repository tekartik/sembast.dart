library sembast.test.database_codec_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'database_format_test.dart' as database_format_test;
import 'encrypt_codec.dart';
import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  // String getDbPath() => ctx.outPath + ".db";
  String dbPath;
  var store = StoreRef.main();

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

  void _commonTests(SembastCodec codec) {
    test('open_a_non_codec_database', () async {
      // Create a non codec database
      var db = await _prepareOneRecordDatabase();
      await db.close();

      // Try to open it using the codec
      try {
        db = await factory.openDatabase(dbPath, codec: codec);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });

    test('open_a_codec database', () async {
      // Create a codec encrypted database
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      // Try to open it without the codec
      try {
        db = await factory.openDatabase(dbPath);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });
  }

  group('codec', () {
    group('json_codec', () {
      var codec = SembastCodec(signature: 'json', codec: MyJsonCodec());
      var codecAlt = SembastCodec(signature: 'json_alt', codec: MyJsonCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('one_record', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        var metaMap = json.decode(lines.first) as Map;
        expect(metaMap,
            {"version": 1, "sembast": 1, 'codec': '{"signature":"json"}'});
        expect(json.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('wrong_signature', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        try {
          await factory.openDatabase(dbPath, codec: codecAlt);
          fail('should fail');
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errInvalidCodec);
        }
      });
    });

    group('base64_random_codec', () {
      var codec = SembastCodec(
          signature: 'base64_random', codec: MyCustomRandomCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);
    });

    group('base64_codec', () {
      var codec = SembastCodec(signature: 'base64', codec: MyCustomCodec());
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('one_record', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();
        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          "version": 1,
          "sembast": 1,
          "codec": 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ=='
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))),
            {'key': 1, 'value': 'test'});

        // reopen
      });

      test('reopen_and_compact', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        db = await factory.openDatabase(dbPath, codec: codec);
        expect(await store.record(1).get(db), 'test');

        await (db as SembastDatabase).compact();

        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          "version": 1,
          "sembast": 1,
          'codec': 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ=='
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))),
            {'key': 1, 'value': 'test'});

        await db.close();
      });
    });

    group('encrypt_codec', () {
      var codec = getEncryptSembastCodec(password: 'user_password');
      database_format_test.defineTests(ctx, codec: codec);
      _commonTests(codec);

      test('read existing', () async {
        dbPath = dbPathFromName(
            'compat/database_code/encrypt_codec/read_existing.db');
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
        List<String> lines = await readContent(fs, dbPath);
        // print(lines);
        expect(lines.length, 2);
        expect(codec.codec.decode(json.decode(lines.first)['codec'] as String),
            {'signature': 'encrypt'});
        expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('reopen_and_compact', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        db = await factory.openDatabase(dbPath, codec: codec);
        expect(await store.record(1).get(db), 'test');

        await (db as SembastDatabase).compact();

        List<String> lines = await readContent(fs, dbPath);
        expect(lines.length, 2);
        expect((json.decode(lines.first) as Map)..remove('codec'), {
          "version": 1,
          "sembast": 1,
        });
        expect(codec.codec.decode(json.decode(lines.first)['codec'] as String),
            {'signature': 'encrypt'});

        expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});

        await db.close();
      });

      test('open with wrong password', () async {
        var db = await _prepareOneRecordDatabase(codec: codec);
        await db.close();

        try {
          var codecWithABadPassword =
              getEncryptSembastCodec(password: "bad_password");
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
  });
}
