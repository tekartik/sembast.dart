library sembast.utils.sembast_import_export;

import '../sembast.dart';
import 'dart:async';

const String _dbVersion = "version";
const String _exportSignatureKey = "sembast_export";
const String _stores = "stores";
const String _name = "name"; // for store
const String _keys = "keys"; // list
const String _values = "values"; // list

const int _exportSignatureVersion = 1;

///
/// Return the data in an exported format that (can be JSONify)
///
Future<Map> exportDatabase(Database db) {
  return db.newTransaction(() async {
    Map export = {
      // our export signature
      _exportSignatureKey: _exportSignatureVersion,
      // the db version
      _dbVersion: db.version
    };

    List<Map> storesExport = [];

    // export all records from each store
    for (Store store in db.stores) {
      List keys = [];
      List values = [];

      Map storeExport = {_name: store.name, _keys: keys, _values: values};

      await store.records.listen((Record record) {
        if (!record.deleted) {
          keys.add(record.key);
          values.add(record.value);
        }
      }).asFuture();

      // Only add store if it has content
      if (keys.isNotEmpty) {
        storesExport.add(storeExport);
      }
    }

    if (storesExport.isNotEmpty) {
      export[_stores] = storesExport;
    }
    return export;
  }) as Future<Map>;
}

///
/// Import the exported data into a new database
///
Future<Database> importDatabase(
    Map srcData, DatabaseFactory dstFactory, String dstPath) async {
  await dstFactory.deleteDatabase(dstPath);

  // check signature
  if (srcData[_exportSignatureKey] != _exportSignatureVersion) {
    throw new FormatException('invalid export format');
  }

  int version = srcData[_dbVersion];

  Database db = await dstFactory.openDatabase(dstPath,
      version: version, mode: DatabaseMode.EMPTY);

  await db.inTransaction(() {
    List<Map> storesExport = srcData[_stores] as List<Map>;
    if (storesExport != null) {
      for (Map storeExport in storesExport) {
        String storeName = storeExport[_name];

        List keys = storeExport[_keys];
        List values = storeExport[_values];

        Store store = db.getStore(storeName);
        for (int i = 0; i < keys.length; i++) {
          store.put(values[i], keys[i]);
        }
      }
    }
  });
  return db;
}
