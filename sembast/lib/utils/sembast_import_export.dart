library sembast.utils.sembast_import_export;

import 'dart:convert';

import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/env_utils.dart';
import 'package:sembast/src/json_utils.dart';
import 'package:sembast/src/model.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
import 'package:sembast/src/transaction_impl.dart';

const String _dbVersion = 'version';
const String _exportSignatureKey = 'sembast_export';
const String _stores = 'stores';
const String _name = 'name'; // for store
const String _keys = 'keys'; // list
const String _values = 'values'; // list
const String _store = 'store'; // store name in export lines
const int _exportSignatureVersion = 1;

///
/// Return the data in an exported format that (can be JSONified).
///
/// An optional [storeNames] can specify the list of stores to export. If null
/// All stores are exported.
///
Future<Map<String, Object?>> exportDatabase(Database db,
    {List<String>? storeNames}) async {
  var export = newModel();
  final storesExport = <Map<String, Object?>>[];
  await _exportDatabase(db, exportMeta: (Model map) {
    export.addAll(map);
  }, exportStore: (Model map) {
    storesExport.add(map);
  }, storeNames: storeNames);

  if (storesExport.isNotEmpty) {
    export[_stores] = storesExport;
  }
  return export;
}

///
/// Return the data in an exported format where each item in the list can be JSONified.
/// If simply encoded as list of json string, it makes it suitable to archive
/// a mutable export on a git file system.
///
/// An optional [storeNames] can specify the list of stores to export. If null
/// All stores are exported.
///
Future<List<Object>> exportDatabaseLines(Database db,
    {List<String>? storeNames}) async {
  var lines = <Object>[];

  await _exportDatabase(db, storeNames: storeNames, exportMeta: (Model map) {
    lines.add(map);
  }, exportStore: (Model map) {
    lines.add(newModel()..[_store] = map[_name]);
    var keys = map[_keys] as List;
    var values = map[_values] as List;
    for (var i = 0; i < keys.length; i++) {
      lines.add([keys[i], values[i]]);
    }
  });

  return lines;
}

///
/// Return the data in an exported format that (can be JSONified).
///
/// An optional [storeNames] can specify the list of stores to export. If null
/// All stores are exported.
///
Future<void> _exportDatabase(Database db,
    {List<String>? storeNames,
    required void Function(Map<String, Object?>) exportMeta,
    required void Function(Map<String, Object?>) exportStore}) {
  return db.transaction((txn) async {
    var metaExport = <String, Object?>{
      // our export signature
      _exportSignatureKey: _exportSignatureVersion,
      // the db version
      _dbVersion: db.version
    };
    exportMeta(metaExport);

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
      final keys = <Object?>[];
      final values = <Object?>[];

      final storeExport = <String, Object?>{
        _name: store.name,
        _keys: keys,
        _values: values
      };

      var currentRecords = store.currentRecords;
      for (var record in currentRecords) {
        keys.add(record.key);
        values.add(sembastDatabase.toJsonEncodable(record.value));
        if (sembastDatabase.cooperator?.needCooperate ?? false) {
          await sembastDatabase.cooperator!.cooperate();
        }
      }

      // Only add store if it has content
      if (keys.isNotEmpty) {
        exportStore(storeExport);
      }
    }
  });
}

///
/// Import the exported data (using exportDatabaseLines) into a new database
///
/// An optional [storeNames] can specify the list of stores to import. If null
/// All stores are exported.
///
Future<Database> importDatabaseLines(
    List srcData, DatabaseFactory dstFactory, String dstPath,
    {SembastCodec? codec, List<String>? storeNames}) async {
  if (srcData.isEmpty) {
    throw const FormatException('invalid export format (empty)');
  }
  Object? metaMap = srcData.first;
  if (metaMap is Map) {
    _checkMeta(metaMap);
  } else {
    throw const FormatException('invalid export format header');
  }
  var mapSrcData = newModel();
  metaMap.forEach((key, value) {
    mapSrcData[key as String] = value;
  });

  String? currentStore;
  var keys = <Object?>[];
  var values = <Object?>[];
  var stores = <Object?>[];
  void closeCurrentStore() {
    if (currentStore != null) {
      if (keys.isNotEmpty) {
        final storeExport = <String, Object?>{
          _name: currentStore,
          _keys: List<Object>.from(keys),
          _values: List<Object>.from(values)
        };
        stores.add(storeExport);
        keys.clear();
        values.clear();
        currentStore = null;
      }
    }
  }

  for (var line in srcData.skip(1)) {
    if (line is Map) {
      closeCurrentStore();
      var storeName = line[_store]?.toString();
      if (storeName != null) {
        currentStore = storeName;
      }
    } else if (currentStore == null) {
      // skipping
    } else if (line is List && currentStore != null) {
      if (line.length >= 2) {
        var key = line[0];
        var value = line[1];
        if (key != null && value != null) {
          keys.add(key);
          values.add(value);
        }
      }
    } else {
      // skipping
    }
  }
  closeCurrentStore();
  mapSrcData[_stores] = stores;
  return await importDatabase(mapSrcData, dstFactory, dstPath,
      codec: codec, storeNames: storeNames);
}

void _checkMeta(Map meta) {
  // check signature
  if (meta[_exportSignatureKey] != _exportSignatureVersion) {
    throw const FormatException('invalid export format');
  }
}

///
/// Import the exported data (using exportDatabase) into a new database
///
/// An optional [storeNames] can specify the list of stores to import. If null
/// All stores are exported.
///
/// If a codec was used, you must specify the same codec for import.
Future<Database> importDatabase(
    Map srcData, DatabaseFactory dstFactory, String dstPath,
    {SembastCodec? codec, List<String>? storeNames}) async {
  await dstFactory.deleteDatabase(dstPath);

  // check signature
  _checkMeta(srcData);

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

        var store = (txn as SembastTransaction)
            .getSembastStore(SembastStoreRef(storeName));
        for (var i = 0; i < keys.length; i++) {
          var key = keys[i] as Object;
          await store.txnPut(
              txn, sembastDatabase.fromJsonEncodable(values[i]), key);
        }
      }
    }
  });
  return db;
}

///
/// Import the exported data (using exportDatabase or exportDatabaseLines or their json encoding or a string of it) into a new database
///
/// An optional [storeNames] can specify the list of stores to import. If null
/// All stores are exported.
///
Future<Database> importDatabaseAny(
    Object srcData, DatabaseFactory dstFactory, String dstPath,
    {SembastCodec? codec, List<String>? storeNames}) {
  Future<Database> mapImport(Map map) {
    return importDatabase(map, dstFactory, dstPath,
        codec: codec, storeNames: storeNames);
  }

  Future<Database> linesImport(List lines) {
    return importDatabaseLines(lines, dstFactory, dstPath,
        codec: codec, storeNames: storeNames);
  }

  srcData = decodeImportAny(srcData);
  try {
    if (srcData is Map) {
      return mapImport(srcData);
    } else if (srcData is List) {
      return linesImport(srcData);
    }
  } catch (e) {
    if (isDebug) {
      // ignore: avoid_print
      print('import error $e');
    }
    throw FormatException('invalid export format (error: $e)');
  }
  throw FormatException('invalid export format (${srcData.runtimeType})');
}

///
/// Decode the exported data to be imported.
///
/// Returns a list of data or a map.
///
Object decodeImportAny(Object srcData) {
  Map mapImport(Map map) {
    return map;
  }

  Object linesImport(List lines) {
    return lines;
  }

  try {
    if (srcData is Map) {
      return mapImport(srcData);
    } else if (srcData is Iterable) {
      if (srcData.isNotEmpty) {
        // First is meta
        if (srcData.first is Map) {
          return linesImport(srcData.toList());
        } else if (srcData.first is String) {
          // list of json string?
          var srcLines = srcData.map((e) => jsonDecode(e.toString())).toList();
          return linesImport(srcLines);
        }
      }
    } else if (srcData is String) {
      // handle multiple json encoding
      Object? srcDecoded;
      try {
        // json ?
        srcDecoded = jsonDecode(srcData.trim()) as Object?;
      } catch (_) {}
      if (srcDecoded is Map || srcDecoded is List) {
        return srcDecoded!;
      }

      var lines = LineSplitter.split(srcData.trim());
      if (lines.isNotEmpty) {
        var srcLines = lines.map((e) => jsonDecode(e)).toList();
        return linesImport(srcLines);
      }
    }
  } catch (e) {
    if (isDebug) {
      // ignore: avoid_print
      print('import error $e');
    }
    throw FormatException('decode invalid export format (error: $e)');
  }
  throw FormatException(
      'decode invalid export format (${srcData.runtimeType})');
}

/// Convert export as a list of string (export is is a List or non null objects)
List<String> exportLinesToJsonStringList(List export) {
  return export.map((e) => jsonEncode(jsonEncodableSort(e as Object))).toList();
}

/// Convert export as a list of string (export is is a List or non null objects)
String exportLinesToJsonlString(List export) => export
    .map((e) => '${jsonEncode(jsonEncodableSort(e as Object))}\n')
    .join('');
