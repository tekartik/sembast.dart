@TestOn('vm')
library sembast.test.database_codec_test;

import 'dart:async';

import 'package:sembast/src/sembast_fs.dart';

import 'test_codecs.dart';
import 'test_common.dart';

void main() {
  defineTests(memoryFileSystemContext);
}

void defineTests(FileSystemTestContext ctx) {
  final fs = ctx.fs;
  DatabaseFactory factory = DatabaseFactoryFs(fs);
  // String getDbPath() => ctx.outPath + '.db';
  late String dbPath;
  var store = StoreRef<int, Object?>.main();

  Future<String> prepareForDb() async {
    dbPath = dbPathFromName('compat/database_codec.db');
    await factory.deleteDatabase(dbPath);
    return dbPath;
  }

  Future<Database> _prepareOneRecordDatabase({SembastCodec? codec}) async {
    await prepareForDb();
    var db = await factory.openDatabase(dbPath, codec: codec);
    await store.add(db, 'test');
    return db;
  }

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
