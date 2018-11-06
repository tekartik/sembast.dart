import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future main() async {
  Database db = await databaseFactoryIo
      .openDatabase(join("example", "io", "test_out", "random.db"));
  /*
  Store store = db.getStore("my_store");
  Record record = new Record(store, {"name": "ugly"});
  record = await db.putRecord(record);
  record = await db.getStoreRecord(store, record.key);
  record = (await db.findStoreRecords(
          store, new Finder(filter: new Filter.byKey(record.key))))
      .first;
  record = await db.getStoreRecord(store, record.key);
  print(record);
  */
  List<Record> records = await db.findRecords(Finder());
  for (Record record in records) {
    print(record);
  }
}
