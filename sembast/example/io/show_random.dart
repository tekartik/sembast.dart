import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

Future main() async {
  final db = await databaseFactoryIo.openDatabase(
    join('example', 'io', 'test_out', 'random.db'),
  );
  var store = StoreRef<Object, Object>.main();
  final records = await store.find(db);
  for (var record in records) {
    print(record);
  }
}
