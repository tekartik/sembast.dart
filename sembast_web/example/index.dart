import 'dart:html';

import 'package:sembast_web/sembast_web.dart';

Database db;
var factory = databaseFactoryWeb;
var counterRecord = StoreRef<String, int>.main().record('counter');
Future main() async {
  db = await factory.openDatabase('sembast_web_example');
  write('hello');

  counterRecord.onSnapshot(db).listen((snapshot) {
    write('onCounter: ${snapshot?.value}');
  });

  querySelector('#add').onClick.listen((_) async {
    await db.transaction((txn) async {
      var value = (await counterRecord.get(txn)) ?? 0;
      write('adding 1 to $value');
      await counterRecord.put(txn, value + 1);
    });
  });
  querySelector('#delete').onClick.listen((_) async {
    write('deleting...');
    await counterRecord.delete(db);
  });
}

class OutBuffer {
  int _maxLineCount;
  List<String> lines = [];

  OutBuffer(int maxLineCount) {
    _maxLineCount = maxLineCount ?? 100;
  }

  void add(String text) {
    lines.add(text);
    while (lines.length > _maxLineCount) {
      lines.removeAt(0);
    }
  }

  @override
  String toString() => lines.join('\n');
}

OutBuffer _outBuffer = OutBuffer(100);
Element _output = document.getElementById('output');
void write([Object message]) {
  print(message);
  _output.text = (_outBuffer..add('$message')).toString();
}
