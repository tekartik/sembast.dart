library sembast.utils.sembast_import_export;

import 'dart:async';

import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

const String _dbVersion = "version";
const String _exportSignatureKey = "sembast_export";
const String _stores = "stores";
const String _name = "name"; // for store
const String _keys = "keys"; // list
const String _values = "values"; // list

const int _exportSignatureVersion = 1;

///
/// Return the data in an exported format that (can be JSONified).
///
Future<Map<String, dynamic>> exportDatabase(v2.Database db) {
  return db.transaction((txn) async {
    var export = <String, dynamic>{
      // our export signature
      _exportSignatureKey: _exportSignatureVersion,
      // the db version
      _dbVersion: db.version
    };

    List<Map> storesExport = [];

    // export all records from each store

    // Make it safe to iterate in an async way
    var sembastDatabase = (txn as SembastTransaction).database;
    var stores = List<SembastStore>.from(sembastDatabase.getCurrentStores());
    for (var store in stores) {
      List keys = [];
      List values = [];

      Map storeExport = {_name: store.store.name, _keys: keys, _values: values};

      for (var record in store.currentRecords) {
        keys.add(record.key);
        values.add(record.value);
        await sembastDatabase.cooperator.cooperate();
      }

      // Only add store if it has content
      if (keys.isNotEmpty) {
        storesExport.add(storeExport);
      }
    }

    if (storesExport.isNotEmpty) {
      export[_stores] = storesExport;
    }
    return export;
  });
}

///
/// Import the exported data into a new database
///
Future<Database> importDatabase(
    Map srcData, DatabaseFactory dstFactory, String dstPath) async {
  await dstFactory.deleteDatabase(dstPath);

  // check signature
  if (srcData[_exportSignatureKey] != _exportSignatureVersion) {
    throw const FormatException('invalid export format');
  }

  int version = srcData[_dbVersion] as int;

  Database db = await dstFactory.openDatabase(dstPath,
      version: version, mode: DatabaseMode.empty);

  await db.transaction((txn) async {
    List<Map> storesExport =
        (srcData[_stores] as Iterable)?.toList(growable: false)?.cast<Map>();
    if (storesExport != null) {
      for (Map storeExport in storesExport) {
        String storeName = storeExport[_name] as String;

        List keys = (storeExport[_keys] as Iterable)?.toList(growable: false);
        List values =
            (storeExport[_values] as Iterable)?.toList(growable: false);

        var store = txn.getStore(storeName);
        for (int i = 0; i < keys.length; i++) {
          await store.put(values[i], keys[i]);
        }
      }
    }
  });
  return db;
}
