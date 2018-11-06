// basically same as the io runner but with extra output
import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future main() async {
  Database db = await databaseFactoryIo
      .openDatabase(join(".dart_tool", "sembast", "example", "record_demo.db"));
  Store store = db.getStore("my_store");
  Record record = Record(store, {"name": "ugly"});
  record = await db.putRecord(record);
  record = await store.getRecord(record.key);
  record =
      (await store.findRecords(Finder(filter: Filter.byKey(record.key)))).first;
  record = await store.getRecord(record.key);
  print(record);
}
