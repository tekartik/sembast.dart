// basically same as the io runner but with extra output
import 'dart:async';

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

Future main() async {
  Database db = await memoryFsDatabaseFactory.openDatabase("record_demo.db");
  Store store = db.getStore("my_store");
  Record record = Record(store, {"name": "ugly"});
  record = await db.putRecord(record);
  record = await store.getRecord(record.key);
  record =
      (await store.findRecords(Finder(filter: Filter.byKey(record.key)))).first;
  record = await store.getRecord(record.key);
  print(record);
}
