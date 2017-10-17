// basically same as the io runner but with extra output
import 'dart:math';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

main() async {
  Database db = await ioDatabaseFactory
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
  int keyCount = 50;
  Random random = new Random();
  while (true) {
    // Put on random key
    var future =
        db.put(new DateTime.now().toString(), random.nextInt(keyCount));
    // randomly wait
    if (random.nextInt(100) == 0) {
      await future;
    }
  }
}
