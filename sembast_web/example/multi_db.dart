import 'package:sembast_web/sembast_web.dart';
import 'package:web/web.dart';

import 'common.dart';

late Database db1;
late Database db2;
var factory = databaseFactoryWeb;
var counterRecord = StoreRef<String, int>.main().record('counter');
Future main() async {
  db1 = await factory.openDatabase('sembast_web_example_multi_db1');
  db2 = await factory.openDatabase('sembast_web_example_multi_db2');
  write('hello multi_db');

  counterRecord.onSnapshot(db1).listen((snapshot) {
    write('onCounter1: ${snapshot?.value}');
  });
  counterRecord.onSnapshot(db2).listen((snapshot) {
    write('onCounter2: ${snapshot?.value}');
  });

  document.querySelector('#add1')!.onClick.listen((_) async {
    await db1.transaction((txn) async {
      var value = (await counterRecord.get(txn)) ?? 0;
      write('DB1 adding 1 to $value');
      await counterRecord.put(txn, value + 1);
    });
  });
  document.querySelector('#delete1')!.onClick.listen((_) async {
    write('DB1 deleting...');
    await counterRecord.delete(db1);
  });
  document.querySelector('#add2')!.onClick.listen((_) async {
    await db2.transaction((txn) async {
      var value = (await counterRecord.get(txn)) ?? 0;
      write('DB2 adding 1 to $value');
      await counterRecord.put(txn, value + 1);
    });
  });
  document.querySelector('#delete2')!.onClick.listen((_) async {
    write('DB2 deleting...');
    await counterRecord.delete(db2);
  });
}
