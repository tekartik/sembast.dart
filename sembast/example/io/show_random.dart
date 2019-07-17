import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future main() async {
  Database db = await databaseFactoryIo
      .openDatabase(join("example", "io", "test_out", "random.db"));
  var store = StoreRef.main();
  List<RecordSnapshot> records = await store.find(db);
  for (var record in records) {
    print(record);
  }
}
