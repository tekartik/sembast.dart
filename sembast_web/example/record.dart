import 'dart:html';

import 'package:sembast_web/sembast_web.dart';

import 'common.dart';

late Database db;
var factory = databaseFactoryWeb;
var counterRecord = StoreRef<String, int>.main().record('counter');
Future main() async {
  db = await factory.openDatabase('sembast_web_example');
  write('hello');

  counterRecord.onSnapshot(db).listen((snapshot) {
    write('onCounter: ${snapshot?.value}');
  });

  querySelector('#add')!.onClick.listen((_) async {
    await db.transaction((txn) async {
      var value = (await counterRecord.get(txn)) ?? 0;
      write('adding 1 to $value');
      await counterRecord.put(txn, value + 1);
    });
  });
  querySelector('#delete')!.onClick.listen((_) async {
    write('deleting...');
    await counterRecord.delete(db);
  });
}
