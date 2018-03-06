// basically same as the io runner but with extra output
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

main() async {
  Database db = await ioDatabaseFactory
      .openDatabase(join("example", "io", "test_out", "record_demo.db"));
  Store store = db.getStore("my_store");
  Record record = new Record(store, {"name": "ugly"});
  record = await db.putRecord(record);
  record = await store.getRecord(record.key);
  record = (await store
          .findRecords(new Finder(filter: new Filter.byKey(record.key))))
      .first;
  record = await store.getRecord(record.key);
  print(record);
}
