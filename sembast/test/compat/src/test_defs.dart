library sembast.test.compat.src.test_defs;

// ignore_for_file: deprecated_member_use_from_same_package
// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast_memory.dart';
import 'package:sembast/src/database_factory_mixin.dart';
import 'package:sembast/src/database_impl.dart';

import '../test_common.dart';

// import 'test_defs_dev.dart';
DatabaseTestContext get memoryDatabaseContext =>
    DatabaseTestContext()..factory = databaseFactoryMemory;

Future<List<Record>> recordStreamToList(Stream<Record> stream) {
  final records = <Record>[];
  return stream
      .listen((Record record) {
        records.add(record);
      })
      .asFuture()
      .then((_) => records);
}

List getRecordsValues(List<Record> records) {
  var list = [];
  for (var record in records) {
    list.add(record.value);
  }
  return list;
}

Future<Database> reOpen(Database db, {DatabaseMode mode}) {
  return (db as SembastDatabase).reOpen(DatabaseOpenOptions(mode: mode));
}
