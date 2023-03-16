// ignore_for_file: invalid_use_of_visible_for_testing_member

library sembast.jdb_database_test;

// ignore: implementation_imports
import 'package:sembast/src/api/protected/jdb.dart';
import 'package:sembast_test/base64_codec.dart';
import 'package:sembast_test/jdb_test_common.dart';

import 'jdb_database_format_test.dart';
import 'test_common.dart';

void main() {
  defineTests(databaseTestContextJdbMemory);
}

void defineTests(DatabaseTestContextJdb ctx) {
  group('jdb_database', () {
    void testWithCodec(SembastCodec? codec) async {
      group('codec ${codec?.signature ?? '<no_signature>'}', () {
        late JdbDatabase database;
        late Database sembastDb;
        var store = StoreRef<int, String>('ts');

        setUp(() async {
          // Clear the database.
          sembastDb = await ctx.open('no_codec.db');
          database = getJdbDatabase(sembastDb);
          //return fs.newFile(dbPath).delete().catchError((_) {});
        });

        tearDown(() {
          sembastDb.close();
        });

        test('addEntry', () async {
          var entry1 = JdbRawWriteEntry(value: 'ho', record: store.record(2));
          expect(entry1.idOrNull, isNull);
          expect(entry1.revision, isNull);
          await database.addEntries([entry1]);
          expect(entry1.idOrNull, isNull);
          expect(entry1.revision, 1);

          var entries = await database.entries.toList();
          expect(entries, hasLength(1));
          var entry = entries.first;
          expect(entry.id, 1);
        });

        test('entriesAfterRevision', () async {
          var entry1 = JdbRawWriteEntry(value: 'ho', record: store.record(2));
          var entry2 = JdbRawWriteEntry(value: 'ha', record: store.record(5));
          var entry3 = JdbRawWriteEntry(value: 'hi', record: store.record(7));
          await database.addEntries([entry1, entry2, entry3]);
          var entries = await database.entries.toList();
          expect(entries, hasLength(3));
          entries = await database.entriesAfterRevision(1).toList();
          expect(entries, hasLength(2));
        });
      });
    }

    testWithCodec(null);
    testWithCodec(
        SembastCodec(signature: 'base64', codec: SembastBase64Codec()));
    testWithCodec(SembastCodec(
        signature: 'async_base64', codec: SembastBase64CodecAsync()));
  }, solo: true);
}
