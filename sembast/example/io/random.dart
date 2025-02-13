import 'dart:async';
import 'dart:math';

import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/database_impl.dart';

Future main() async {
  var db = await databaseFactoryIo.openDatabase(
    join('example', 'io', 'test_out', 'random.db'),
  );
  var store = StoreRef<int, String>.main();
  // randomly write

  final keyCount = 50;
  final random = Random();
  while (true) {
    // Put on random key
    var future = store
        .record(random.nextInt(keyCount))
        .put(db, DateTime.now().toString());
    // randomly wait
    if (random.nextInt(100) == 0) {
      await future;
    }

    if (random.nextInt(1000) == 0) {
      print('reopening');
      db = await (db as SembastDatabase).reOpen();
    }
  }
}
