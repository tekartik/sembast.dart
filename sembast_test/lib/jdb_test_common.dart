import 'package:sembast/src/api/v2/sembast_memory.dart';
import 'package:sembast/src/jdb.dart';
import 'package:sembast/src/sembast_jdb.dart';

import 'test_common.dart';

class DatabaseTestContextJdb extends DatabaseTestContext {
  JdbFactory get jdbFactory => (factory as DatabaseFactoryJdb).jdbFactory;
}

DatabaseTestContextJdb get databaseTestContextJdbMemory =>
    DatabaseTestContextJdb()..factory = databaseFactoryMemoryJdb;

///
/// helper to read a list of string (lines). unsafe
///
Future jdbImportFromMap(JdbFactory jdbFactory, String name, Map map) async {
  var jdb = await jdbFactory.open(name);
  await jdbDatabaseImportFromMap(jdb, map);
  await jdb.close();
}

Future jdbDatabaseImportFromMap(JdbDatabase jdb, Map map) async {
  // Clear all before import
  await jdb.clearAll();
  var entries = (map['entries'] as List)?.cast<Map>()?.map((map) {
    var valueMap = map['value'] as Map;
    var storeName = valueMap['store'] as String;
    var store = storeName == null ? StoreRef.main() : StoreRef(storeName);
    return JdbRawWriteEntry(
        deleted: valueMap['deleted'] as bool,
        value: valueMap['value'],
        record: store.record(valueMap['key']))
      ..id = valueMap['id'] as int;
  })?.toList(growable: false);
  if (entries?.isNotEmpty ?? false) {
    await jdb.addEntries(entries);
  }
  var infos = (map['infos'] as List)
      ?.cast<Map>()
      ?.map((map) => JdbInfoEntry()
        ..id = map['id'] as String
        ..value = map['value'])
      ?.toList(growable: false);
  if (infos?.isNotEmpty ?? false) {
    for (var info in infos) {
      await jdb.setInfoEntry(info);
    }
  }
}
