@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/api/protected/codec.dart'
    show sembastCodecDefaultV2;
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/import_export_io.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:test/test.dart';

/// The example files, the same database:
/// - legacy_export1.jsonl: the legacy export (`@Timestamp`, `@Blob`), it must
///   never change.
/// - dollar_export1.jsonl: the `$` export (`$timestamp`, `$blob`).
/// - sembast_io_db1.jsonl: the sembast io database file.
String _dataPath(String name) => join('test', 'src', 'data', name);

final _legacyExport1Path = _dataPath('legacy_export1.jsonl');
final _dollarExport1Path = _dataPath('dollar_export1.jsonl');
final _sembastIoDb1Path = _dataPath('sembast_io_db1.jsonl');

final _typeStore = StoreRef<String, Object>('type');
final _mainStore = StoreRef<int, String>.main();

/// The content of a test data file with \n line endings (a Windows checkout
/// can turn them into \r\n).
Future<String> _readData(String path) async =>
    (await File(path).readAsString()).replaceAll('\r\n', '\n');

/// Root of the io files written by the tests.
final _ioTestPath = join('.local', 'test', 'sembast_export_format_io');

/// The example database: the types encoded in an export (Timestamp, Blob)
/// and the maps looking like an encoded type.
Future<Database> _createDb1(
  DatabaseFactory factory,
  String path, {
  SembastCodec? codec,
}) async {
  await factory.deleteDatabase(path);
  var db = await factory.openDatabase(path, version: 1, codec: codec);
  await _typeStore
      .record('timestamp')
      .put(db, Timestamp(1793622600, 123456000));
  await _typeStore.record('blob').put(db, Blob(Uint8List.fromList([1, 2, 3])));
  await _typeStore.record('map').put(db, {
    'int': 1,
    'double': 4.5,
    'bool': true,
    'string': 'text',
    'null': null,
    'list': [1, 'two', Timestamp(0, 0)],
    'timestamp': Timestamp(1793622600, 0),
    'blob': Blob(Uint8List.fromList([255])),
    'nested': {'blob': Blob(Uint8List.fromList([]))},
  });
  await _typeStore.record('escaped').put(db, {'@Timestamp': 'not a timestamp'});
  await _typeStore.record('escaped_at').put(db, {'@': 1});
  await _typeStore.record('escaped_dollar').put(db, {r'$blob': 'not a blob'});
  await _mainStore.record(1).put(db, 'hi');
  return db;
}

/// The content of the example database.
Future<void> _checkDb1(Database db) async {
  expect(db.version, 1);
  expect(
    await _typeStore.record('timestamp').get(db),
    Timestamp(1793622600, 123456000),
  );
  expect(
    await _typeStore.record('blob').get(db),
    Blob(Uint8List.fromList([1, 2, 3])),
  );
  expect(await _typeStore.record('map').get(db), {
    'blob': Blob(Uint8List.fromList([255])),
    'bool': true,
    'double': 4.5,
    'int': 1,
    'list': [1, 'two', Timestamp(0, 0)],
    'nested': {'blob': Blob(Uint8List.fromList([]))},
    'null': null,
    'string': 'text',
    'timestamp': Timestamp(1793622600, 0),
  });
  expect(await _typeStore.record('escaped').get(db), {
    '@Timestamp': 'not a timestamp',
  });
  expect(await _typeStore.record('escaped_at').get(db), {'@': 1});
  expect(await _typeStore.record('escaped_dollar').get(db), {
    r'$blob': 'not a blob',
  });
  expect(await _mainStore.record(1).get(db), 'hi');
  expect(await _typeStore.count(db), 6);
}

/// The jsonl export of [db].
Future<String> _exportJsonl(
  Database db, {
  SembastExportTypeEncoding? typeEncoding,
}) async => exportLinesToJsonlString(
  await exportDatabaseLines(
    db,
    options: SembastExportOptions(typeEncoding: typeEncoding),
  ),
);

void main() {
  late String legacyExport1;
  late String dollarExport1;
  late String sembastIoDb1;
  setUpAll(() async {
    legacyExport1 = await _readData(_legacyExport1Path);
    dollarExport1 = await _readData(_dollarExport1Path);
    sembastIoDb1 = await _readData(_sembastIoDb1Path);
  });

  group('legacy export', () {
    test('format', () {
      expect(
        legacyExport1.split('\n').first,
        '{"sembast_export":1,"version":1}',
      );
      expect(legacyExport1, contains('{"@Timestamp":'));
      expect(legacyExport1, contains('{"@Blob":'));
      expect(legacyExport1, isNot(contains('type_prefix')));
    });

    test('export', () async {
      var db = await _createDb1(newDatabaseFactoryMemory(), 'db1.db');
      try {
        expect(await _exportJsonl(db), legacyExport1);
        // An explicit @ export of an @ database is the legacy one.
        expect(
          await _exportJsonl(db, typeEncoding: SembastExportTypeEncoding.at),
          legacyExport1,
        );
        // The map export, same content.
        var map = await exportDatabase(db);
        expect(map['sembast_export'], 1);
        expect(map.containsKey('type_prefix'), isFalse);
      } finally {
        await db.close();
      }
    });

    test('import, re-export', () async {
      for (var allowed in [
        null,
        [SembastExportTypeEncoding.at],
        SembastExportTypeEncoding.values,
      ]) {
        var db = await importDatabaseFromFile(
          _legacyExport1Path,
          newDatabaseFactoryMemory(),
          'imported.db',
          options: SembastImportOptions(allowedTypeEncodings: allowed),
        );
        try {
          await _checkDb1(db);
          expect(await _exportJsonl(db), legacyExport1);
          expect(
            await _exportJsonl(
              db,
              typeEncoding: SembastExportTypeEncoding.dollar,
            ),
            dollarExport1,
          );
        } finally {
          await db.close();
        }
      }
    });

    test('import from the map export', () async {
      var db = await _createDb1(newDatabaseFactoryMemory(), 'db1.db');
      var map = await exportDatabase(db);
      await db.close();
      db = await importDatabase(map, newDatabaseFactoryMemory(), 'imported.db');
      try {
        await _checkDb1(db);
        expect(await _exportJsonl(db), legacyExport1);
      } finally {
        await db.close();
      }
    });

    test('import restricted to dollar', () async {
      expect(
        () => importDatabaseFromFile(
          _legacyExport1Path,
          newDatabaseFactoryMemory(),
          'imported.db',
          options: const SembastImportOptions(
            allowedTypeEncodings: [SembastExportTypeEncoding.dollar],
          ),
        ),
        throwsFormatException,
      );
    });

    test('io file export', () async {
      var db = await importDatabaseFromFile(
        _legacyExport1Path,
        newDatabaseFactoryMemory(),
        'imported.db',
      );
      var file = join(_ioTestPath, 'legacy_export1.jsonl');
      try {
        await exportDatabaseToJsonlFile(db, file);
      } finally {
        await db.close();
      }
      expect(await File(file).readAsString(), legacyExport1);
    });
  });

  group('dollar export', () {
    test('format', () {
      expect(
        dollarExport1.split('\n').first,
        r'{"sembast_export":1,"type_prefix":"$","version":1}',
      );
      expect(dollarExport1, contains(r'{"$Timestamp":'));
      expect(dollarExport1, contains(r'{"$Blob":'));
      expect(dollarExport1, isNot(contains('"@Timestamp":"2')));
      expect(dollarExport1, isNot(contains('"@Blob"')));
    });

    test('export', () async {
      var db = await _createDb1(newDatabaseFactoryMemory(), 'db1.db');
      try {
        expect(
          await _exportJsonl(
            db,
            typeEncoding: SembastExportTypeEncoding.dollar,
          ),
          dollarExport1,
        );
        var map = await exportDatabase(
          db,
          options: const SembastExportOptions(
            typeEncoding: SembastExportTypeEncoding.dollar,
          ),
        );
        expect(map['type_prefix'], r'$');
      } finally {
        await db.close();
      }
    });

    test('import, re-export', () async {
      for (var allowed in [
        null,
        [SembastExportTypeEncoding.dollar],
        SembastExportTypeEncoding.values,
      ]) {
        var db = await importDatabaseFromFile(
          _dollarExport1Path,
          newDatabaseFactoryMemory(),
          'imported.db',
          options: SembastImportOptions(allowedTypeEncodings: allowed),
        );
        try {
          await _checkDb1(db);
          expect(
            await _exportJsonl(
              db,
              typeEncoding: SembastExportTypeEncoding.dollar,
            ),
            dollarExport1,
          );
          expect(await _exportJsonl(db), legacyExport1);
        } finally {
          await db.close();
        }
      }
    });

    test('import restricted to at', () async {
      expect(
        () => importDatabaseFromFile(
          _dollarExport1Path,
          newDatabaseFactoryMemory(),
          'imported.db',
          options: const SembastImportOptions(
            allowedTypeEncodings: [SembastExportTypeEncoding.at],
          ),
        ),
        throwsFormatException,
      );
    });

    test('type names as is', () async {
      // The type names are the adapter names, no case conversion:
      // {"$timestamp": ...} is not a Timestamp in a default database.
      var camel = dollarExport1.replaceFirst(
        r'["timestamp",{"$Timestamp":',
        r'["timestamp",{"$timestamp":',
      );
      var db = await importDatabaseAny(
        camel,
        newDatabaseFactoryMemory(),
        'imported.db',
      );
      try {
        expect(await _typeStore.record('timestamp').get(db), {
          r'$timestamp': '2026-11-02T12:30:00.123456Z',
        });
      } finally {
        await db.close();
      }
    });

    test('unknown type prefix', () async {
      var lines = decodeImportAny(dollarExport1) as List;
      lines[0] = {'sembast_export': 1, 'version': 1, 'type_prefix': '#'};
      expect(
        () => importDatabaseLines(lines, newDatabaseFactoryMemory(), 'x.db'),
        throwsFormatException,
      );
    });
  });

  group('V2 codec database', () {
    // A database whose codec uses $ (sembastCodecDefaultV2).
    test('export, import', () async {
      var factory = newDatabaseFactoryMemory();
      var db = await _createDb1(factory, 'v2.db', codec: sembastCodecDefaultV2);
      try {
        await _checkDb1(db);
        // Unchanged legacy behavior: the values in the database codec, no
        // type_prefix.
        var noOption = await _exportJsonl(db);
        expect(noOption.split('\n').first, '{"sembast_export":1,"version":1}');
        expect(noOption, contains(r'{"$timestamp":'));
        // The explicit encodings keep the type names of the codec
        // (timestamp, blob), only the prefix changes.
        var dollar = await _exportJsonl(
          db,
          typeEncoding: SembastExportTypeEncoding.dollar,
        );
        expect(
          dollar.split('\n').first,
          r'{"sembast_export":1,"type_prefix":"$","version":1}',
        );
        expect(dollar.split('\n').skip(1), noOption.split('\n').skip(1));
        var at = await _exportJsonl(
          db,
          typeEncoding: SembastExportTypeEncoding.at,
        );
        expect(
          at.split('\n').first,
          '{"sembast_export":1,"type_prefix":"@","version":1}',
        );
        expect(at, contains('["timestamp",{"@timestamp":'));

        // Imported back in a V2 database: its own exports.
        for (var export in [noOption, at, dollar]) {
          var imported = await importDatabaseAny(
            export,
            factory,
            'v2_imported.db',
            codec: sembastCodecDefaultV2,
          );
          try {
            await _checkDb1(imported);
          } finally {
            await imported.close();
          }
        }
        // The exports of a default database (Timestamp, Blob) keep their
        // types as maps in a V2 database (timestamp, blob): no name
        // conversion, like the legacy export.
        for (var (export, key) in [
          (legacyExport1, '@Timestamp'),
          (dollarExport1, r'$Timestamp'),
        ]) {
          var imported = await importDatabaseAny(
            export,
            factory,
            'v2_imported.db',
            codec: sembastCodecDefaultV2,
          );
          try {
            expect(await _typeStore.record('timestamp').get(imported), {
              key: '2026-11-02T12:30:00.123456Z',
            });
          } finally {
            await imported.close();
          }
        }
      } finally {
        await db.close();
      }
    });
  });

  group('sembast io db file', () {
    test('import writes the example file', () async {
      var path = join(_ioTestPath, 'sembast_io_db1.db');
      var db = await importDatabaseFromFile(
        _legacyExport1Path,
        databaseFactoryIo,
        path,
      );
      await db.close();
      expect(await File(path).readAsString(), sembastIoDb1);
    });

    test('open, export', () async {
      // Written, a database file can be rewritten when opened.
      var path = join(_ioTestPath, 'sembast_io_db1_copy.db');
      await Directory(_ioTestPath).create(recursive: true);
      await File(path).writeAsString(sembastIoDb1);
      var db = await databaseFactoryIo.openDatabase(path);
      try {
        await _checkDb1(db);
        expect(await _exportJsonl(db), legacyExport1);
        expect(
          await _exportJsonl(
            db,
            typeEncoding: SembastExportTypeEncoding.dollar,
          ),
          dollarExport1,
        );
      } finally {
        await db.close();
      }
      expect(await File(path).readAsString(), sembastIoDb1);
    });
  });
}
