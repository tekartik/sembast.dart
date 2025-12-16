// ignore_for_file: implementation_imports
import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast_test/src/import_database.dart';

import 'src/import_jdb.dart';
import 'test_common.dart';

export 'package:sembast_web/src/jdb_factory_idb.dart' show JdbFactoryIdb;

class DatabaseTestContextJdb extends DatabaseTestContext {
  JdbFactory get jdbFactory => (factory as DatabaseFactoryJdb).jdbFactory;
}

DatabaseTestContextJdb get databaseTestContextJdbMemory =>
    DatabaseTestContextJdb()..factory = databaseFactoryMemoryJdb;

///
/// helper to read a list of string (lines). unsafe
///
Future<void> jdbImportFromMap(
  JdbFactory jdbFactory,
  String name,
  Map map,
) async {
  var jdb = await jdbFactory.open(name, DatabaseOpenOptions());
  await jdbDatabaseImportFromMap(jdb, map);
  jdb.close();
}

Future<void> jdbDatabaseImportFromMap(JdbDatabase jdb, Map map) async {
  // Clear all before import
  await jdb.clearAll();
  var entries = (map['entries'] as List?)
      ?.cast<Map>()
      .map((map) {
        var valueMap = map['value'] as Map;
        var storeName = valueMap['store'] as String?;
        var store = storeName == null
            ? StoreRef<Object, Object>.main()
            : StoreRef<Object, Object>(storeName);
        return JdbRawWriteEntry(
          deleted: (valueMap['deleted'] as bool?) ?? false,
          value: valueMap['value'],
          record: store.record(valueMap['key'] as Object),
        );
      })
      .toList(growable: false);
  if (entries?.isNotEmpty ?? false) {
    await jdb.addEntries(entries!);
  }
  var infos = (map['infos'] as List?)
      ?.cast<Map>()
      .map(
        (map) => JdbInfoEntry()
          ..id = map['id'] as String?
          ..value = map['value'],
      )
      .toList(growable: false);
  if (infos?.isNotEmpty ?? false) {
    for (var info in infos!) {
      await jdb.setInfoEntry(info);
    }
  }
}
