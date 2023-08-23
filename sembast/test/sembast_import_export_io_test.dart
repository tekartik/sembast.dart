@TestOn('vm')
library sembast.sembast_import_export_io_test;

// basically same as the io runner but with extra output

import 'package:path/path.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/import_export_io.dart';

import 'jdb_test_common.dart';

void main() {
  group('sembast_import_export_io', () {
    test('import', () async {
      var file = join('test', 'src', 'data', 'export1.jsonl');
      var db = await importDatabaseFromFile(
          file, newDatabaseFactoryMemory(), 'test');
      expect(await StoreRef.main().record(1).get(db), 'hi');
    });
    test('export', () async {
      var db = await newDatabaseFactoryMemory().openDatabase('src');
      await StoreRef.main().record(1).put(db, 'test2');
      var file = join('.local', 'test', 'export', 'export2.jsonl');
      await exportDatabaseToJsonlFile(db, file);

      db = await importDatabaseFromFile(
          file, newDatabaseFactoryMemory(), 'test');
      expect(await StoreRef.main().record(1).get(db), 'test2');
    });
  });
}
