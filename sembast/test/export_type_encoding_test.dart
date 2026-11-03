library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/api/protected/codec.dart'
    show sembastCodecDefaultV2;
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:sembast/utils/type_adapter.dart';
import 'package:test/test.dart';

/// The $ and @ combinations of the export type encodings:
/// - export: database codec (default @, V2 $, custom adapter) x
///   typeEncoding (none, at, dollar);
/// - import: header (legacy: none, type_prefix @, type_prefix $) x encoded
///   value spelling (prefix, case) x destination database codec;
/// - import restrictions (allowedTypeEncodings).

final _store = StoreRef<String, Object>('s');

const _iso = '2026-11-02T12:30:00.000Z';
final _timestamp = Timestamp.parse(_iso);
final _blob = Blob(Uint8List.fromList([1, 2, 3]));
const _blobBase64 = 'AQID';

/// A custom type with a PascalCase adapter name.
class _Point {
  _Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is _Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

class _Converter<S, T> extends Converter<S, T> {
  _Converter(this._convert);

  final T Function(S input) _convert;

  @override
  T convert(S input) => _convert(input);
}

class _PointAdapter extends SembastTypeAdapter<_Point, String> {
  @override
  String get name => 'MyPoint';

  @override
  bool isType(Object? value) => value is _Point;

  @override
  Converter<_Point, String> get encoder =>
      _Converter((point) => '${point.x},${point.y}');

  @override
  Converter<String, _Point> get decoder => _Converter((text) {
    var parts = text.split(',');
    return _Point(int.parse(parts[0]), int.parse(parts[1]));
  });
}

final _customCodec = SembastCodec(
  signature: null,
  codec: null,
  jsonEncodableCodec: JsonEncodableCodec(
    adapters: [...sembastDefaultTypeAdapters, _PointAdapter()],
  ),
);

/// The destination/source database codecs, null being the default one.
final _codecs = <String, SembastCodec?>{
  'default': null,
  'v2': sembastCodecDefaultV2,
  'custom': _customCodec,
};

const _legacyHeader = {'sembast_export': 1, 'version': 1};
Map<String, Object?> _header(String prefix) => {
  ..._legacyHeader,
  'type_prefix': prefix,
};

/// The value of the record 'k' after importing [value] with [header].
Future<Object?> _importValue(
  Map header,
  Object value, {
  SembastCodec? codec,
  List<SembastExportTypeEncoding>? allowed,
}) async {
  var db = await importDatabaseLines(
    [
      header,
      {'store': 's'},
      ['k', value],
    ],
    newDatabaseFactoryMemory(),
    'import.db',
    codec: codec,
    options: SembastImportOptions(allowedTypeEncodings: allowed),
  );
  try {
    return await _store.record('k').get(db);
  } finally {
    await db.close();
  }
}

/// A plain map (not decoded).
Object? _same(Object value) => value;

void main() {
  group('import', () {
    // (header name, header, destination codecs, encoded, expected)
    var cases =
        <(String, Map, List<String>, Map<String, Object?>, Object? Function())>[
          // Legacy export (no type_prefix): decoded by the destination codec,
          // the name case must match exactly (unchanged legacy behavior).
          ...[
            ({'@Timestamp': _iso}, () => _timestamp),
            ({'@Blob': _blobBase64}, () => _blob),
            ({'@timestamp': _iso}, () => _same({'@timestamp': _iso})),
            ({r'$timestamp': _iso}, () => _same({r'$timestamp': _iso})),
            ({r'$Timestamp': _iso}, () => _same({r'$Timestamp': _iso})),
            (
              {
                '@': {'@Timestamp': 'x'},
              },
              () => {'@Timestamp': 'x'},
            ),
            (
              {
                r'$': {r'$blob': 'x'},
              },
              () => _same({
                r'$': {r'$blob': 'x'},
              }),
            ),
            ({'@Foo': 1}, () => _same({'@Foo': 1})),
            (
              {'@Timestamp': 'not a date'},
              () => _same({'@Timestamp': 'not a date'}),
            ),
          ].map(
            (c) => ('legacy', _legacyHeader, ['default', 'custom'], c.$1, c.$2),
          ),
          ...[
            ({r'$timestamp': _iso}, () => _timestamp),
            ({r'$blob': _blobBase64}, () => _blob),
            ({r'$Timestamp': _iso}, () => _same({r'$Timestamp': _iso})),
            ({'@Timestamp': _iso}, () => _same({'@Timestamp': _iso})),
            (
              {
                r'$': {r'$blob': 'x'},
              },
              () => {r'$blob': 'x'},
            ),
          ].map((c) => ('legacy', _legacyHeader, ['v2'], c.$1, c.$2)),
          // type_prefix $: the type names of the database codec as is
          // (Timestamp, Blob; timestamp, blob for V2), an @ key is data.
          ...[
            ({r'$Timestamp': _iso}, () => _timestamp),
            ({r'$Blob': _blobBase64}, () => _blob),
            ({r'$timestamp': _iso}, () => _same({r'$timestamp': _iso})),
            ({r'$blob': _blobBase64}, () => _same({r'$blob': _blobBase64})),
            ({r'$TIMESTAMP': _iso}, () => _same({r'$TIMESTAMP': _iso})),
            ({'@Timestamp': _iso}, () => _same({'@Timestamp': _iso})),
            ({'@Blob': _blobBase64}, () => _same({'@Blob': _blobBase64})),
            (
              {
                r'$': {r'$Blob': 'x'},
              },
              () => {r'$Blob': 'x'},
            ),
            (
              {
                '@': {'@Timestamp': 'x'},
              },
              () => _same({
                '@': {'@Timestamp': 'x'},
              }),
            ),
            ({r'$foo': 1}, () => _same({r'$foo': 1})),
            (
              {
                'list': [
                  {r'$Timestamp': _iso},
                  {r'$Blob': _blobBase64},
                ],
              },
              () => {
                'list': [_timestamp, _blob],
              },
            ),
          ].map(
            (c) => (
              r'type_prefix $',
              _header(r'$'),
              ['default', 'custom'],
              c.$1,
              c.$2,
            ),
          ),
          ...[
            ({r'$timestamp': _iso}, () => _timestamp),
            ({r'$blob': _blobBase64}, () => _blob),
            ({r'$Timestamp': _iso}, () => _same({r'$Timestamp': _iso})),
            ({'@timestamp': _iso}, () => _same({'@timestamp': _iso})),
          ].map((c) => (r'type_prefix $', _header(r'$'), ['v2'], c.$1, c.$2)),
          // type_prefix @: the type names of the database codec as is, a $
          // key is data.
          ...[
            ({'@Timestamp': _iso}, () => _timestamp),
            ({'@Blob': _blobBase64}, () => _blob),
            ({'@timestamp': _iso}, () => _same({'@timestamp': _iso})),
            ({r'$Timestamp': _iso}, () => _same({r'$Timestamp': _iso})),
            (
              {
                '@': {'@Timestamp': 'x'},
              },
              () => {'@Timestamp': 'x'},
            ),
            (
              {
                r'$': {r'$blob': 'x'},
              },
              () => _same({
                r'$': {r'$blob': 'x'},
              }),
            ),
          ].map(
            (c) => (
              'type_prefix @',
              _header('@'),
              ['default', 'custom'],
              c.$1,
              c.$2,
            ),
          ),
          ...[
            ({'@timestamp': _iso}, () => _timestamp),
            ({'@blob': _blobBase64}, () => _blob),
            ({'@Timestamp': _iso}, () => _same({'@Timestamp': _iso})),
          ].map((c) => ('type_prefix @', _header('@'), ['v2'], c.$1, c.$2)),
          // The custom adapter (MyPoint), its name as is.
          ...[
            ({'@MyPoint': '1,2'}, () => _Point(1, 2)),
            ({'@myPoint': '1,2'}, () => _same({'@myPoint': '1,2'})),
          ].map((c) => ('legacy', _legacyHeader, ['custom'], c.$1, c.$2)),
          ...[
            ({r'$MyPoint': '1,2'}, () => _Point(1, 2)),
            ({r'$myPoint': '1,2'}, () => _same({r'$myPoint': '1,2'})),
          ].map(
            (c) => (r'type_prefix $', _header(r'$'), ['custom'], c.$1, c.$2),
          ),
          ...[
            ({'@MyPoint': '1,2'}, () => _Point(1, 2)),
            ({'@myPoint': '1,2'}, () => _same({'@myPoint': '1,2'})),
          ].map((c) => ('type_prefix @', _header('@'), ['custom'], c.$1, c.$2)),
        ];
    for (var (headerName, header, codecNames, encoded, expected) in cases) {
      for (var codecName in codecNames) {
        test('$headerName ${jsonEncode(encoded)} in $codecName', () async {
          expect(
            await _importValue(header, encoded, codec: _codecs[codecName]),
            expected(),
          );
        });
      }
    }
  });

  group('import restriction', () {
    const at = SembastExportTypeEncoding.at;
    const dollar = SembastExportTypeEncoding.dollar;
    // (header name, header, allowed, accepted)
    var cases = <(String, Map, List<SembastExportTypeEncoding>?, bool)>[
      ('legacy', _legacyHeader, null, true),
      ('legacy', _legacyHeader, [at], true),
      ('legacy', _legacyHeader, [at, dollar], true),
      ('legacy', _legacyHeader, [dollar], false),
      ('legacy', _legacyHeader, [], false),
      ('type_prefix @', _header('@'), null, true),
      ('type_prefix @', _header('@'), [at], true),
      ('type_prefix @', _header('@'), [dollar], false),
      (r'type_prefix $', _header(r'$'), null, true),
      (r'type_prefix $', _header(r'$'), [dollar], true),
      (r'type_prefix $', _header(r'$'), [at, dollar], true),
      (r'type_prefix $', _header(r'$'), [at], false),
      (r'type_prefix $', _header(r'$'), [], false),
      ('type_prefix #', _header('#'), null, false),
      ('type_prefix 1', {..._legacyHeader, 'type_prefix': 1}, null, false),
    ];
    for (var (headerName, header, allowed, accepted) in cases) {
      test('$headerName allowed ${allowed?.map((e) => e.name)}', () async {
        Future<Object?> import() =>
            _importValue(header, {'v': 1}, allowed: allowed);
        if (accepted) {
          expect(await import(), {'v': 1});
        } else {
          await expectLater(import, throwsFormatException);
        }
      });
    }
  });

  group('export', () {
    /// The exported record value, with plain maps looking like encoded
    /// types.
    Map<String, Object?> value() => {
      'timestamp': _timestamp,
      'blob': _blob,
      'atData': {'@Timestamp': 'x'},
      'dollarData': {r'$blob': 'x'},
    };

    /// The encoded value of [value] with [prefix] and the type names of the
    /// codec as is (Timestamp, Blob; timestamp, blob for [v2]).
    Map<String, Object?> encoded(String prefix, {bool v2 = false}) {
      var timestamp = v2 ? 'timestamp' : 'Timestamp';
      var blob = v2 ? 'blob' : 'Blob';
      return {
        'timestamp': {'$prefix$timestamp': _iso},
        'blob': {'$prefix$blob': _blobBase64},
        // The plain maps looking like a type of the prefix are escaped.
        'atData': prefix == '@'
            ? {
                '@': {'@Timestamp': 'x'},
              }
            : {'@Timestamp': 'x'},
        'dollarData': prefix == r'$'
            ? {
                r'$': {r'$blob': 'x'},
              }
            : {r'$blob': 'x'},
      };
    }

    // (source codec, typeEncoding, header type_prefix, encoded value)
    var cases =
        <(String, SembastExportTypeEncoding?, String?, Map<String, Object?>)>[
          ('default', null, null, encoded('@')),
          ('default', SembastExportTypeEncoding.at, null, encoded('@')),
          ('default', SembastExportTypeEncoding.dollar, r'$', encoded(r'$')),
          // Unchanged legacy behavior: the values in the database codec.
          ('v2', null, null, encoded(r'$', v2: true)),
          ('v2', SembastExportTypeEncoding.at, '@', encoded('@', v2: true)),
          (
            'v2',
            SembastExportTypeEncoding.dollar,
            r'$',
            encoded(r'$', v2: true),
          ),
          ('custom', null, null, encoded('@')),
          ('custom', SembastExportTypeEncoding.at, null, encoded('@')),
          ('custom', SembastExportTypeEncoding.dollar, r'$', encoded(r'$')),
        ];
    for (var (codecName, typeEncoding, typePrefix, encoded) in cases) {
      test('$codecName ${typeEncoding?.name}', () async {
        var codec = _codecs[codecName];
        var db = await newDatabaseFactoryMemory().openDatabase(
          'export.db',
          codec: codec,
        );
        try {
          await _store.record('k').put(db, value());
          var lines = await exportDatabaseLines(
            db,
            options: SembastExportOptions(typeEncoding: typeEncoding),
          );
          expect(lines.first, {
            'sembast_export': 1,
            'version': 1,
            'type_prefix': ?typePrefix,
          });
          expect(lines.last, ['k', encoded]);
          var map = await exportDatabase(
            db,
            options: SembastExportOptions(typeEncoding: typeEncoding),
          );
          expect(map['type_prefix'], typePrefix);

          // An export imports in a database with the same type names (no name
          // conversion).
          for (var dstCodecName in _codecs.keys) {
            var sameNames = (codecName == 'v2') == (dstCodecName == 'v2');
            if (!sameNames) {
              continue;
            }
            var imported = await importDatabaseLines(
              lines,
              newDatabaseFactoryMemory(),
              'imported.db',
              codec: _codecs[dstCodecName],
            );
            try {
              expect(
                await _store.record('k').get(imported),
                value(),
                reason: 'imported in $dstCodecName',
              );
            } finally {
              await imported.close();
            }
          }
        } finally {
          await db.close();
        }
      });
    }

    test('custom adapter', () async {
      var db = await newDatabaseFactoryMemory().openDatabase(
        'export.db',
        codec: _customCodec,
      );
      try {
        await _store.record('k').put(db, {'point': _Point(1, 2)});
        Future<Object> export(SembastExportTypeEncoding? typeEncoding) async =>
            (await exportDatabaseLines(
              db,
              options: SembastExportOptions(typeEncoding: typeEncoding),
            )).last;
        expect(await export(null), [
          'k',
          {
            'point': {'@MyPoint': '1,2'},
          },
        ]);
        expect(await export(SembastExportTypeEncoding.at), [
          'k',
          {
            'point': {'@MyPoint': '1,2'},
          },
        ]);
        expect(await export(SembastExportTypeEncoding.dollar), [
          'k',
          {
            'point': {r'$MyPoint': '1,2'},
          },
        ]);
      } finally {
        await db.close();
      }
    });
  });
}
