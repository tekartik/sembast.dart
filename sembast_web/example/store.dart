import 'package:sembast_web/sembast_web.dart';
import 'package:web/web.dart';

import 'common.dart';

late Database db;
var factory = databaseFactoryWeb;

Future main() async {
  await run(dbName: 'sembast_web_example_store', store: null);
}

Future run({required String dbName, String? store}) async {
  var dateStore = store == null
      ? StoreRef<int, String>.main()
      : StoreRef<int, String>(store);

  db = await factory.openDatabase(dbName);
  write('hello');

  dateStore.query().onSnapshots(db).listen((snapshots) {
    write('onSnapshots: ${snapshots.length} item(s)');
    for (var snapshot in snapshots) {
      write('[${snapshot.key}]: ${snapshot.value}');
    }
  });

  document.querySelector('#add')!.onClick.listen((_) async {
    var key = await dateStore.add(db, DateTime.now().toIso8601String());
    write('add now $key');
  });
  document.querySelector('#delete')!.onClick.listen((_) async {
    write('deleting...');
    await dateStore.delete(db);
  });
}
