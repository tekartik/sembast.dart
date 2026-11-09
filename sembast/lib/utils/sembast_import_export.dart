library;

import 'dart:convert';

import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/sembast.dart';
import 'package:sembast/src/common_import.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/env_utils.dart';
import 'package:sembast/src/export_type_encoding.dart';
import 'package:sembast/src/import_export_options.dart';
import 'package:sembast/src/json_encodable_codec.dart';
import 'package:sembast/src/json_utils.dart';
import 'package:sembast/src/model.dart';
import 'package:sembast/src/store_impl.dart';
import 'package:sembast/src/store_ref_impl.dart';
import 'package:sembast/src/transaction_impl.dart';
export 'package:sembast/sembast.dart';
export 'package:sembast/src/export_type_encoding.dart'
    show SembastExportTypeEncoding;
export 'package:sembast/src/import_export_options.dart'
    show SembastExportOptions, SembastImportOptions;

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
/// See [exportDatabaseLines] for [client] and [options].
Future<Map<String, Object?>> exportDatabase(
  DatabaseClient client, {
  List<String>? storeNames,
  SembastExportOptions? options,
}) async {
  var export = newModel();
  final storesExport = <Map<String, Object?>>[];
  await _exportDatabase(
    client,
    typeEncoding: options?.typeEncoding,
    exportMeta: (Model map) {
      export.addAll(map);
    },
    exportStore: (Model map) {
      storesExport.add(map);
    },
    storeNames: options?.storeNames ?? storeNames,
  );

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
/// [options] can give the stores to export (overriding [storeNames]) and the
/// encoding of the custom types. Without a type encoding (the legacy export),
/// the custom types are encoded by the database codec (`@Timestamp`, `@Blob`
/// by default). With one, they are encoded in it (`$Timestamp`, `$Blob` for
/// [SembastExportTypeEncoding.dollar]) and the header gives it
/// (`{"sembast_export": 1, "version": 1, "type_prefix": "$"}`, the import
/// reads it). [SembastExportTypeEncoding.at] from a database whose codec uses
/// `@` is the legacy export.
///
/// [client] is a database or a transaction. In a transaction, the export
/// runs in it and includes its changes: writing and exporting can happen in
/// the same transaction.
Future<List<Object>> exportDatabaseLines(
  DatabaseClient client, {
  List<String>? storeNames,
  SembastExportOptions? options,
}) async {
  var lines = <Object>[];

  await _exportDatabase(
    client,
    typeEncoding: options?.typeEncoding,
    storeNames: options?.storeNames ?? storeNames,
    exportMeta: (Model map) {
      lines.add(map);
    },
    exportStore: (Model map) {
      lines.add(newModel()..[_store] = map[_name]);
      var keys = map[_keys] as List;
      var values = map[_values] as List;
      for (var i = 0; i < keys.length; i++) {
        lines.add([keys[i], values[i]]);
      }
    },
  );

  return lines;
}

///
/// Return the data in an exported format that (can be JSONified).
///
/// An optional [storeNames] can specify the list of stores to export. If null
/// All stores are exported.
///
Future<void> _exportDatabase(
  DatabaseClient client, {
  List<String>? storeNames,
  SembastExportTypeEncoding? typeEncoding,
  required void Function(Map<String, Object?>) exportMeta,
  required void Function(Map<String, Object?>) exportStore,
}) {
  // In the transaction of the client, a new one for a database.
  return getClient(client).inTransaction((txn) async {
    // Make it safe to iterate in an async way
    var sembastDatabase = txn.database;

    var metaExport = <String, Object?>{
      // our export signature
      _exportSignatureKey: _exportSignatureVersion,
      // the db version
      _dbVersion: sembastDatabase.version,
    };
    var toJsonEncodable = sembastDatabase.toJsonEncodable;
    if (typeEncoding != null) {
      var dbCodec = _databaseJsonEncodableCodec(sembastDatabase);
      // An @ export of an @ database is the legacy one.
      if (typeEncoding != SembastExportTypeEncoding.at ||
          dbCodec.prefix != SembastExportTypeEncoding.at.prefix) {
        metaExport[sembastExportTypePrefixKey] = typeEncoding.prefix;
        toJsonEncodable = sembastExportTypeEncodingCodec(
          typeEncoding,
          jsonEncodableCodecAdapters(dbCodec),
        ).encode;
      }
    }
    exportMeta(metaExport);

    // export all records from each store

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
        _values: values,
      };

      // The records seen by the transaction (its changes included), sorted
      // by key.
      var currentRecords = await store.txnFindRecords(txn, null);
      for (var record in currentRecords) {
        keys.add(record.key);
        values.add(toJsonEncodable(record.value));
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
  List srcData,
  DatabaseFactory dstFactory,
  String dstPath, {
  SembastCodec? codec,
  List<String>? storeNames,
  SembastImportOptions? options,
}) async {
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
          _values: List<Object>.from(values),
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
  return await importDatabase(
    mapSrcData,
    dstFactory,
    dstPath,
    codec: codec,
    storeNames: storeNames,
    options: options,
  );
}

/// The json encodable codec of [db], the default one if none.
JsonEncodableCodec _databaseJsonEncodableCodec(SembastDatabase db) =>
    db.openOptions.codec?.jsonEncodableCodec ??
    sembastDefaultJsonEncodableCodec;

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
///
/// The custom types are decoded in the encoding given by the export header
/// (`type_prefix`, see [exportDatabaseLines]), a legacy export (no
/// `type_prefix`) by the database [codec]. [options] can give the stores to
/// import (overriding [storeNames]) and restrict the accepted type encodings
/// (a legacy export being [SembastExportTypeEncoding.at]), all are accepted
/// by default; another one throws a [FormatException].
Future<Database> importDatabase(
  Map srcData,
  DatabaseFactory dstFactory,
  String dstPath, {
  SembastCodec? codec,
  List<String>? storeNames,
  SembastImportOptions? options,
}) async {
  storeNames = options?.storeNames ?? storeNames;
  // Checked before deleting the destination.
  // check signature
  _checkMeta(srcData);
  var typeEncoding = sembastExportHeaderTypeEncoding(
    srcData,
    allowed: options?.allowedTypeEncodings,
  );
  await dstFactory.deleteDatabase(dstPath);

  final version = srcData[_dbVersion] as int?;

  final db = await dstFactory.openDatabase(
    dstPath,
    version: version,
    mode: DatabaseMode.empty,
    codec: codec,
  );
  var sembastDatabase = db as SembastDatabase;
  var fromJsonEncodable = typeEncoding == null
      ? sembastDatabase.fromJsonEncodable
      : sembastExportTypeEncodingCodec(
          typeEncoding,
          jsonEncodableCodecAdapters(
            _databaseJsonEncodableCodec(sembastDatabase),
          ),
        ).decode;
  await db.transaction((txn) async {
    final storesExport = (srcData[_stores] as Iterable?)
        ?.toList(growable: false)
        .cast<Map>();
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

        var store = (txn as SembastTransaction).getSembastStore(
          SembastStoreRef(storeName),
        );
        for (var i = 0; i < keys.length; i++) {
          var key = keys[i] as Object;
          await store.txnPut(txn, fromJsonEncodable(values[i]), key);
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
  Object srcData,
  DatabaseFactory dstFactory,
  String dstPath, {
  SembastCodec? codec,
  List<String>? storeNames,
  SembastImportOptions? options,
}) {
  Future<Database> mapImport(Map map) {
    return importDatabase(
      map,
      dstFactory,
      dstPath,
      codec: codec,
      storeNames: storeNames,
      options: options,
    );
  }

  Future<Database> linesImport(List lines) {
    return importDatabaseLines(
      lines,
      dstFactory,
      dstPath,
      codec: codec,
      storeNames: storeNames,
      options: options,
    );
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
    'decode invalid export format (${srcData.runtimeType})',
  );
}

/// Convert export as a list of string (export is is a List or non null objects)
List<String> exportLinesToJsonStringList(List export) {
  return export.map((e) => jsonEncode(jsonEncodableSort(e as Object))).toList();
}

/// Convert export as a list of string (export is is a List or non null objects)
String exportLinesToJsonlString(List export) => export
    .map((e) => '${jsonEncode(jsonEncodableSort(e as Object))}\n')
    .join('');
