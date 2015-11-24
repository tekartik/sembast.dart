library sembast.utils.sembast_import_export;

import '../sembast.dart';
import 'dart:async';

const String _db_version = "version";
const String _exportSignatureVersion = "sembast_export";
const String _stores = "stores";
const String _name = "name"; // for store
const String _keys = "keys"; // list
const String _values = "values"; // list

Future<Map> exportDatabase(Database db) async {
  return db.newTransaction(() async {
    Map export = {
      // our export signature
      _exportSignatureVersion: 1,
      // the db version
      _db_version: db.version
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
  });
}
