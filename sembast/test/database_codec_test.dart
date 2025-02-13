@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/src/async_content_codec.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/src/timestamp_impl.dart';

import 'database_format_test.dart' as database_format_test;
import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  // String getDbPath() => ctx.outPath + '.db';
  String? dbPath;
  var store = StoreRef<int, Object>.main();

  Future<String?> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_codec.db');
    await factory.deleteDatabase(dbPath!);
    return dbPath;
  }

  Future<Database> prepareOneRecordDatabase({SembastCodec? codec}) async {
    await prepareForDb();
    var db = await factory.openDatabase(dbPath!, codec: codec);
    await store.add(db, 'test');
    return db;
  }

  void commonTests(SembastCodec codec) {
    test('open_a_non_codec_database', () async {
      // Create a non codec database
      var db = await prepareOneRecordDatabase();
      await db.close();

      // Try to open it using the codec
      try {
        db = await factory.openDatabase(dbPath!, codec: codec);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });

    test('open_a_codec database', () async {
      // Create a codec encrypted database
      var db = await prepareOneRecordDatabase(codec: codec);
      await db.close();

      // Try to open it without the codec
      try {
        db = await factory.openDatabase(dbPath!);
        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }
    });

    test('custom type', () async {
      // Create a codec encrypted database
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, codec: codec);
      var key = await store.add(db, Timestamp(1, 2));
      await db.close();

      db = await factory.openDatabase(dbPath!, codec: codec);
      expect(await store.record(key).get(db), Timestamp(1, 2));
      await db.close();
    });
  }

  group('codec', () {
    group('json_codec', () {
      var codec = SembastCodec(signature: 'json', codec: MyJsonCodec());
      var codecAlt = SembastCodec(signature: 'json_alt', codec: MyJsonCodec());
      database_format_test.defineTestsWithCodec(ctx, codec: codec);
      commonTests(codec);

      test('one_record', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();
        final lines = await readContent(fs, dbPath!);
        expect(lines.length, 2);
        var metaMap = json.decode(lines.first) as Map?;
        expect(metaMap, {
          'version': 1,
          'sembast': 1,
          'codec': '{"signature":"json"}',
        });
        expect(json.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('wrong_signature', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();
        try {
          await factory.openDatabase(dbPath!, codec: codecAlt);
          fail('should fail');
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errInvalidCodec);
        }
      });
    });

    group('async_json_codec', () {
      var codec = SembastCodec(
        signature: 'json',
        codec: AsyncContentJsonCodec(),
      );
      var codecAlt = SembastCodec(
        signature: 'json_alt',
        codec: AsyncContentJsonCodec(),
      );
      database_format_test.defineTestsWithCodec(ctx, codec: codec);
      commonTests(codec);

      test('one_record', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();
        final lines = await readContent(fs, dbPath!);
        expect(lines.length, 2);
        var metaMap = json.decode(lines.first) as Map?;
        expect(metaMap, {
          'version': 1,
          'sembast': 1,
          'codec': '{"signature":"json"}',
        });
        expect(json.decode(lines[1]), {'key': 1, 'value': 'test'});
      });

      test('wrong_signature', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();
        try {
          await factory.openDatabase(dbPath!, codec: codecAlt);
          fail('should fail');
        } on DatabaseException catch (e) {
          expect(e.code, DatabaseException.errInvalidCodec);
        }
      });
    });

    group('codec_throw', () {
      var codecDecoderThrow = SembastCodec(
        signature: 'json',
        codec: MyJsonCodecDecoderThrow(),
      );
      var codecEncoderThrow = SembastCodec(
        signature: 'json',
        codec: MyJsonCodecEncoderThrow(),
      );

      test('decode_throw', () async {
        var db = await prepareOneRecordDatabase(codec: codecDecoderThrow);
        await db.close();

        db = await factory.openDatabase(dbPath!, codec: codecEncoderThrow);
        expect((await store.find(db)).map((e) => e.value), ['test']);
        await db.close();

        await expectLater(
          factory.openDatabase(dbPath!, codec: codecDecoderThrow),
          throwsA(isA<Exception>()),
        );
      });
      test('encode_throw', () async {
        await prepareForDb();
        // If codec fails, the error is transferred
        await expectLater(
          factory.openDatabase(dbPath!, codec: codecEncoderThrow),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('base64_random_codec', () {
      var codec = SembastCodec(
        signature: 'base64_random',
        codec: MyCustomRandomCodec(),
      );
      database_format_test.defineTestsWithCodec(ctx, codec: codec);
      commonTests(codec);
    });

    group('base64_codec', () {
      var codec = SembastCodec(signature: 'base64', codec: MyCustomCodec());
      database_format_test.defineTestsWithCodec(ctx, codec: codec);
      commonTests(codec);

      test('one_record', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();
        final lines = await readContent(fs, dbPath!);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          'version': 1,
          'sembast': 1,
          'codec': 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ==',
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))), {
          'key': 1,
          'value': 'test',
        });

        // reopen
      });

      test('reopen_and_compact', () async {
        var db = await prepareOneRecordDatabase(codec: codec);
        await db.close();

        db = await factory.openDatabase(dbPath!, codec: codec);
        expect(await store.record(1).get(db), 'test');

        await (db as SembastDatabase).compact();
        final lines = await readContent(fs, dbPath!);
        expect(lines.length, 2);
        expect(json.decode(lines.first), {
          'version': 1,
          'sembast': 1,
          'codec': 'eyJzaWduYXR1cmUiOiJiYXNlNjQifQ==',
        });
        expect(json.decode(utf8.decode(base64.decode(lines[1]))), {
          'key': 1,
          'value': 'test',
        });

        await db.close();
      });
    });
  });
}
