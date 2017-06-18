// basically same as the io runner but with extra output
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

main() async {
  Database db = await memoryFsDatabaseFactory.openDatabase("record_demo.db");
  Store store = db.getStore("my_store");
  Record record = new Record(store, {"name": "ugly"});
  record = await db.putRecord(record);
  record = await db.getStoreRecord(store, record.key);
  record = (await db.findStoreRecords(
          store, new Finder(filter: new Filter.byKey(record.key))))
      .first;
  record = await db.getStoreRecord(store, record.key);
  print(record);
}
