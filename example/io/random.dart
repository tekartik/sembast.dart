import 'dart:math';
import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/src/database_impl.dart';

main() async {
  Database db = await ioDatabaseFactory
      .openDatabase(join("example", "io", "test_out", "random.db"));

  // randomly write

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

    if (random.nextInt(1000) == 0) {
      print('reopening');
      await (db as SembastDatabase).reOpen();
    }
  }
}
