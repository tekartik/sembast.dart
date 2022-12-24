library sembast.utils.sembast_import_export;

import 'dart:async';

import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

const String _dbVersion = 'version';
const String _exportSignatureKey = 'sembast_export';
const String _stores = 'stores';
const String _name = 'name'; // for store
const String _keys = 'keys'; // list
const String _values = 'values'; // list

const int _exportSignatureVersion = 1;

///
/// Return the data in an exported format that (can be JSONified).
///
/// An optional [storeNames] can specify the list of stores to export. If null
/// All stores are exported.
///
Future<Map<String, Object?>> exportDatabase(Database db,
    {List<String>? storeNames}) {
  return db.transaction((txn) async {
    var export = <String, Object?>{
      // our export signature
      _exportSignatureKey: _exportSignatureVersion,
      // the db version
      _dbVersion: db.version
    };

    final storesExport = <Map<String, Object?>>[];

    // export all records from each store

    // Make it safe to iterate in an async way
    var sembastDatabase = (txn as SembastTransaction).database;
    var stores = List<SembastStore>.from(sembastDatabase.getCurrentStores());
    // Filter stores
    if (storeNames != null) {
      stores.removeWhere((store) => !storeNames.contains(store.name));
    }
    stores.sort((store1, store2) => store1.name.compareTo(store2.name));

    for (var store in stores) {
      final keys = [];
      final values = [];

      final storeExport = <String, Object?>{
        _name: store.name,
        _keys: keys,
        _values: values
      };

      for (var record in store.currentRecords) {
        keys.add(record.key);
        values.add(sembastDatabase.toJsonEncodable(record.value!));
        if (sembastDatabase.cooperator?.needCooperate ?? false) {
          await sembastDatabase.cooperator!.cooperate();
        }
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
/// An optional [storeNames] can specify the list of stores to import. If null
/// All stores are exported.
///
Future<Database> importDatabase(
    Map srcData, DatabaseFactory dstFactory, String dstPath,
    {SembastCodec? codec, List<String>? storeNames}) async {
  await dstFactory.deleteDatabase(dstPath);

  // check signature
  if (srcData[_exportSignatureKey] != _exportSignatureVersion) {
    throw const FormatException('invalid export format');
  }

  final version = srcData[_dbVersion] as int?;

  final db = await dstFactory.openDatabase(dstPath,
      version: version, mode: DatabaseMode.empty, codec: codec);
  var sembastDatabase = db as SembastDatabase;
  await db.transaction((txn) async {
    final storesExport =
        (srcData[_stores] as Iterable?)?.toList(growable: false).cast<Map>();
    if (storesExport != null) {
      for (var storeExport in storesExport) {
        final storeName = storeExport[_name] as String;

        // Filter store
        if (storeNames != null) {
          if (!storeNames.contains(storeName)) {
            continue;
          }
        }

        final keys = (storeExport[_keys] as Iterable).toList(growable: false);
        final values = List<Object>.from(storeExport[_values] as Iterable);

        var store =
            (txn as SembastTransaction).getSembastStore(StoreRef(storeName));
        for (var i = 0; i < keys.length; i++) {
          await store.txnPut(
              txn, sembastDatabase.fromJsonEncodable(values[i]), keys[i]);
        }
      }
    }
  });
  return db;
}
