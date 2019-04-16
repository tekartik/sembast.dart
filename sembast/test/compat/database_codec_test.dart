library sembast.database_codec_test;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

import 'database_format_test.dart' as database_format_test;
import 'test_common.dart';
import 'xxtea_codec.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

class MyJsonEncoder extends Converter<Map<String, dynamic>, String> {
  @override
  String convert(Map<String, dynamic> input) => json.encode(input);
}

class MyJsonDecoder extends Converter<String, Map<String, dynamic>> {
  @override
  Map<String, dynamic> convert(String input) {
    var result = json.decode(input);
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

class MyJsonCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyJsonDecoder();
  @override
  final encoder = MyJsonEncoder();
}

class MyCustomEncoder extends Converter<Map<String, dynamic>, String> {
  @override
  String convert(Map<String, dynamic> input) =>
      base64.encode(utf8.encode(json.encode(input)));
}

class MyCustomDecoder extends Converter<String, Map<String, dynamic>> {
  @override
  Map<String, dynamic> convert(String input) {
    var result = json.decode(utf8.decode(base64.decode(input)));
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    throw FormatException('invalid input $input');
  }
}

/// Simple codec that encode in base 64
class MyCustomCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyCustomDecoder();
  @override
  final encoder = MyCustomEncoder();
}

class MyCustomRandomEncoder extends MyCustomEncoder {
  @override
  String convert(Map<String, dynamic> input) {
    if (input != null) {
      input = Map<String, dynamic>.from(input);
      input['_custom_seed'] = Random().nextInt(1000);
    }
    return super.convert(input);
  }
}

class MyCustomRandomDecoder extends MyCustomDecoder {
  @override
  Map<String, dynamic> convert(String input) {
    var map = super.convert(input);
    if (map is Map) {
      map = Map<String, dynamic>.from(map);
      map.remove('_custom_seed');
    }
    return map;
  }
}

/// Simple codec that encode in base 64 with an added seed
class MyCustomRandomCodec extends Codec<Map<String, dynamic>, String> {
  @override
  final decoder = MyCustomRandomDecoder();
  @override
  final encoder = MyCustomRandomEncoder();
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  String getDbPath() => ctx.outPath + ".db";
  String dbPath;

  Future<String> prepareForDb() async {
    dbPath = getDbPath();
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  Future<Database> _prepareOneRecordDatabase({SembastCodec codec}) async {
    await prepareForDb();
    var db = await factory.openDatabase(dbPath, codec: codec);
    await db.put('test');
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
  });

  group('base64_random_codec', () {
    var codec =
        SembastCodec(signature: 'base64_random', codec: MyCustomRandomCodec());
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
      expect(await db.get(1), 'test');

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

  group('xxtea_codec', () {
    var codec = getXXTeaSembastCodec(password: 'user_password');
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
        "codec": 'f6BJnfYOYu/JYOG/5AOmVAMjGZ+/av6MZi6+3g=='
      });
      expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});
    });

    test('reopen_and_compact', () async {
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await db.get(1), 'test');

      await (db as SembastDatabase).compact();

      List<String> lines = await readContent(fs, dbPath);
      expect(lines.length, 2);
      expect(json.decode(lines.first), {
        "version": 1,
        "sembast": 1,
        'codec': 'f6BJnfYOYu/JYOG/5AOmVAMjGZ+/av6MZi6+3g=='
      });
      expect(codec.codec.decode(lines[1]), {'key': 1, 'value': 'test'});

      await db.close();
    });

    test('open with wrong password', () async {
      var db = await _prepareOneRecordDatabase(codec: codec);
      await db.close();

      try {
        var codecWithABadPassword =
            getXXTeaSembastCodec(password: "bad_password");
        // Open again with a bad password
        db = await factory.openDatabase(dbPath, codec: codecWithABadPassword);

        fail('should fail');
      } on DatabaseException catch (e) {
        expect(e.code, DatabaseException.errInvalidCodec);
      }

      // Open again with the proper password
      db = await factory.openDatabase(dbPath, codec: codec);
      expect(await db.get(1), 'test');
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
