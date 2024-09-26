library;

import 'package:sembast/timestamp.dart';
import 'package:sembast_test/base64_codec.dart';

import 'test_common.dart';

void main() {
  defineTests(memoryDatabaseContext);
}

void defineTests(DatabaseTestContext ctx) {
  var factory = ctx.factory;
  group('codec', () {
    test('export', () async {
      var path = dbPathFromName('codec/base64.db');
      await factory.deleteDatabase(path);
      var codec =
          SembastCodec(signature: 'base64', codec: SembastBase64Codec());
      var store = StoreRef<String, Object>.main();
      var record = store.record('key');
      var recordTimestamp = store.record('timestamp');
      await factory.deleteDatabase('test');
      var db = await factory.openDatabase(path, codec: codec);
      expect(await record.get(db), isNull);
      await record.put(db, 'value');
      await recordTimestamp.put(db, Timestamp(1, 2));
      expect(await record.get(db), 'value');
      await db.close();

      db = await factory.openDatabase(path, codec: codec);
      expect(await record.get(db), 'value');
      await recordTimestamp.put(db, Timestamp(1, 2));
      await record.put(db, 'value2');
      expect(await record.get(db), 'value2');
      await db.close();
    });
  });
}
