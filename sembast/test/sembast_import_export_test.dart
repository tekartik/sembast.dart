library;

// basically same as the io runner but with extra output

import 'dart:convert';

import 'package:sembast/utils/sembast_import_export.dart';
// ignore_for_file: implementation_imports
import 'package:test/test.dart';

void main() {
  group('sembast_import_export', () {
    test('api', () {
      // ignore: unnecessary_statements
      decodeImportAny;
    });
    test('decodeImportAny', () {
      var exportLines = [
        {'sembast_export': 1, 'version': 3},
        {'store': '_main'},
        [1, 'hi'],
      ];
      expect(decodeImportAny(exportLines), exportLines);
      expect(
        decodeImportAny(exportLines.map((e) => jsonEncode(e))),
        exportLines,
      );
      expect(decodeImportAny(jsonEncode(exportLines)), exportLines);
      expect(exportLinesToJsonlString(exportLines), '''
{"sembast_export":1,"version":3}
{"store":"_main"}
[1,"hi"]
''');
      exportLines = [
        {'sembast_export': 1, 'version': 3},
      ];
      expect(decodeImportAny(exportLines), exportLines);
      expect(
        decodeImportAny(exportLines.map((e) => jsonEncode(e))),
        exportLines,
      );
      expect(decodeImportAny(jsonEncode(exportLines)), exportLines);
    });
  });
}
