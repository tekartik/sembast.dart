import 'dart:async';

// ignore: implementation_imports
import 'package:sembast/src/async_content_codec.dart';

// ignore: implementation_imports
import 'package:sembast/src/timestamp_impl.dart';
import 'package:sembast_test/fs_test_common.dart';

import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFsDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;
  String? dbPath;
  var store = StoreRef<int, Object>.main();

  Future<String> prepareForDb() async {
    var path = dbPath = dbPathFromName('compat/database_codec.db');
    await factory.deleteDatabase(path);
    return path;
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
      var dbPath = await prepareForDb();
      var db = await factory.openDatabase(dbPath, codec: codec);
      var key = await store.add(db, Timestamp(1, 2));
      await db.close();

      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await store.record(key).get(db), Timestamp(1, 2));
      await db.close();
    });
  }

  group('codec', () {
    group('json_codec', () {
      var codec = SembastCodec(signature: 'json', codec: MyJsonCodec());
      var codecAlt = SembastCodec(signature: 'json_alt', codec: MyJsonCodec());
      commonTests(codec);

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
      commonTests(codec);

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
      try {
        test('encode_throw', () async {
          var dbPath = await prepareForDb();
          // If codec fails, the error is transferred
          await expectLater(
            factory.openDatabase(dbPath, codec: codecEncoderThrow),
            throwsA(isA<StateError>()),
          );

          // Open without codec to make sure the db is closed
          var db = await factory.openDatabase(dbPath);
          await db.close();
        });
      } catch (e, s) {
        print(s);
      }
    });

    group('base64_random_codec', () {
      var codec = SembastCodec(
        signature: 'base64_random',
        codec: MyCustomRandomCodec(),
      );
      commonTests(codec);
    });

    group('base64_codec', () {
      var codec = SembastCodec(signature: 'base64', codec: MyCustomCodec());
      commonTests(codec);
    });
  });
}
