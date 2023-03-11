library sembast.database_format_test;

import 'dart:async';
import 'dart:convert';

import 'package:sembast/src/database_impl.dart';
import 'package:sembast/src/sembast_codec_impl.dart';
import 'package:sembast/src/sembast_fs.dart';
import 'package:sembast/timestamp.dart';

import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
  defineTestsWithCodec(memoryFileSystemContext);
}

Map mapWithoutCodec(Map map) {
  return Map.from(map)..remove('codec');
}

// Whether our test codec use random initialization value
bool _hasRandomIv(SembastCodec? codec) {
  // Hardcoded for ou custom random codec and our encrypt codec
  return (codec?.codec is MyCustomRandomCodec) ||
      (codec?.signature == 'encrypt');
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  //String getDbPath() => ctx.outPath + '.db';
  late String dbPath;

  Future<String> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_format.db');
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  test('corrupted non-utf8', () async {
    await prepareForDb();
    await writeContent(fs, dbPath, [
      '{"version":2,"sembast":1}',
      '{"key":1,"store":"test","value":1}',
      String.fromCharCodes([195, 9]),
      '{"key":3,"store":"test","value":3}'
    ]);
    var store = StoreRef<int, int>('test');
    final db = await factory.openDatabase(dbPath);
    expect(db.version, 2);
    print(await store.find(db));
    expect(await store.count(db), 2);
    await db.close();
  });
}

void defineTestsWithCodec(FileSystemTestContext ctx, {SembastCodec? codec}) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  //String getDbPath() => ctx.outPath + '.db';
  String? dbPath;
  var store = StoreRef<int, String>.main();

  Future<String?> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_format.db');
    await factory.deleteDatabase(dbPath!);
    return dbPath;
  }

  group('basic format', () {
    setUp(() {
      //return fs.newFile(dbPath).delete().catchError((_) {});
    });

    tearDown(() {});

    test('open_no_version', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, codec: codec);
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 1);
      var expected = <String, Object?>{'version': 1, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.first) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature},
            reason: 'lines: $lines');
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.first), expected);
      }
    });

    test('open_version_2', () async {
      await prepareForDb();
      await factory.openDatabase(dbPath!, version: 2, codec: codec);
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 1);
      var expected = <String, Object?>{'version': 2, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.first) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.first), expected);
      }
    });

    List<Map?> linesAsMapList(List<String> lines) {
      return lines
          .map((line) => json.decode(line) as Map?)
          .toList(growable: false);
    }

    test('open_version_1_then_2', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 1, codec: codec);
      await db.close();
      db = await factory.openDatabase(dbPath!, version: 2, codec: codec);
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      if (codec == null) {
        expect(linesAsMapList(lines), [
          {'version': 1, 'sembast': 1},
          {'version': 2, 'sembast': 1}
        ]);
      }

      var expected = <String, Object?>{'version': 2, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.last) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.last), expected);
      }

      await db.close();
      db = await factory.openDatabase(dbPath!, codec: codec);
      expect(db.version, 2);
      await db.close();
    });

    dynamic decodeRecord(String line) {
      if (codec?.codec != null) {
        return codec!.codec!.decode(line);
      } else {
        return json.decode(line);
      }
    }

    test('1 string record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, codec: codec);
      await store.record(1).put(db, 'hi');
      await db.close();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
    });

    test('1_record_in_2_stores', () async {
      await prepareForDb();
      final db = await factory.openDatabase(dbPath!, codec: codec);
      (db as SembastDatabase).getSembastStore(StoreRef('store1'));
      db.getSembastStore(StoreRef('store2'));
      await StoreRef<int, Object>('store2').record(1).put(db, 'hi');
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      expect(
          decodeRecord(lines[1]), {'store': 'store2', 'key': 1, 'value': 'hi'});
    });

    test('twice same record', () async {
      await prepareForDb();
      var record = store.record(1);
      var db = await factory.openDatabase(dbPath!, codec: codec);
      await record.put(db, 'hi');
      await record.put(db, 'hi');
      await db.close();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 3);
      expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
      expect(decodeRecord(lines[2]), {'key': 1, 'value': 'hi'});
    });

    test('1 map record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      var store = intMapStoreFactory.store();
      var record = store.record(1);
      await record.put(db, {'test': 2});
      await db.close();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      expect(json.decode(lines[1]), {
        'key': 1,
        'value': {'test': 2}
      });
    });

    test('1 custom type record', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!);
      var store = intMapStoreFactory.store();
      var record = store.record(1);
      await record.put(db, <String, Object?>{'test': Timestamp(1, 2)});
      await db.close();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      expect(json.decode(lines[1]), {
        'key': 1,
        'value': {
          'test': {'@Timestamp': '1970-01-01T00:00:01.000000002Z'}
        }
      });
    });

    test('1_record_in_open', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 2,
          onVersionChanged: (db, _, __) async {
        await store.record(1).put(db, 'hi');
      }, codec: codec);
      await db.close();
      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      var expected = <String, Object?>{'version': 2, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.first) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.first), expected);
      }
      expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
    });

    test('1_record_in_open_transaction', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, version: 2,
          onVersionChanged: (db, _, __) async {
        await db.transaction((txn) async {
          await store.record(1).put(txn, 'hi');
        });
      }, codec: codec);
      await db.close();
      final lines = await readContent(fs, dbPath!);
      expect(lines.length, 2);
      var expected = <String, Object?>{'version': 2, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.first) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.first), expected);
      }
      expect(decodeRecord(lines[1]), {'key': 1, 'value': 'hi'});
    });

    test('open_version_1_then_2_then_compact', () async {
      await prepareForDb();
      var db = await factory.openDatabase(dbPath!, codec: codec);
      await store.add(db, 'test1');
      await db.close();
      db = await factory.openDatabase(dbPath!, version: 2, codec: codec);

      await store.add(db, 'test2');
      await db.close();

      var lines = await readContent(fs, dbPath!);
      expect(lines.length, 4);
      var expected = <String, Object?>{'version': 1, 'sembast': 1};
      if (codec != null) {
        expected['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(lines.first) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        expect(json.decode(lines.first), expected);
      }

      var expectedV2 = <String, Object?>{'version': 2, 'sembast': 1};

      if (codec != null) {
        expectedV2['codec'] = getCodecEncodedSignature(codec);
        var line = lines[2];
        var map = json.decode(line) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        var line = lines[2];
        expect(json.decode(line), expectedV2);
      }

      await db.close();

      db = await factory.openDatabase(dbPath!, codec: codec);
      var record1 = store.record(1);
      var record2 = store.record(2);
      expect(await record1.get(db), 'test1');
      expect(await record2.get(db), 'test2');
      expect((await readContent(fs, dbPath!)).length, 4);
      await (db as SembastDatabase).compact();

      lines = await readContent(fs, dbPath!);
      expect(lines.length, 3);
      if (codec != null) {
        var line = lines[0];
        expectedV2['codec'] = getCodecEncodedSignature(codec);
        var map = json.decode(line) as Map;
        expect(getCodecDecodedSignature(codec, map['codec'] as String?),
            {'signature': codec.signature});
      }
      if (!_hasRandomIv(codec)) {
        var line = lines[0];
        expect(json.decode(line), expectedV2);
      }

      await db.close();

      db = await factory.openDatabase(dbPath!, codec: codec);
      expect(await record1.get(db), 'test1');
      expect(await record2.get(db), 'test2');
      await db.close();
    });
  });

  group('format_import', () {
    test('open_version_2', () async {
      await prepareForDb();
      await writeContent(fs, dbPath!, [
        json.encode({
          'version': 2,
          'sembast': 1,
          'codec': getCodecEncodedSignature(codec)
        })
      ]);
      return factory.openDatabase(dbPath!, codec: codec).then((Database db) {
        expect(db.version, 2);
      });
    });
  });

  group('corrupted', () {
    test('corrupted', () async {
      await prepareForDb();
      await writeContent(fs, dbPath!, ['corrupted']);

      Future deleteFile(String path) {
        return fs.file(path).delete();
      }

      Database db;
      try {
        db = await factory.openDatabase(dbPath!,
            codec: codec, mode: DatabaseMode.create);
        fail('should fail');
      } on FormatException catch (_) {
        await deleteFile(dbPath!);
        db = await factory.openDatabase(dbPath!, codec: codec);
      }
      expect(db.version, 1);
      await db.close();
    });

    test('corrupted_open_empty', () async {
      await prepareForDb();
      await writeContent(fs, dbPath!, ['corrupted_option_empty']);
      final db = await factory.openDatabase(dbPath!,
          mode: DatabaseMode.empty, codec: codec);
      expect(db.version, 1);
      await db.close();
    });
  });
}
