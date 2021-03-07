// basically same as the io runner but with extra output
import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future main() async {
  final db = await databaseFactoryIo
      .openDatabase(join('.dart_tool', 'sembast', 'example', 'record_demo.db'));
  var store = intMapStoreFactory.store('my_store');

  var key = await store.add(db, {'name': 'ugly'});
  var record = await (store.record(key).getSnapshot(db)
      as FutureOr<RecordSnapshot<int, Map<String, Object>>>);
  record =
      (await store.find(db, finder: Finder(filter: Filter.byKey(record.key))))
          .first as RecordSnapshot<int, Map<String, Object>>;
  print(record);
  var records = (await (store.find(db,
          finder: Finder(filter: Filter.matches('name', '^ugly')))
      as FutureOr<List<RecordSnapshot<int, Map<String, Object>>>>));
  print(records);
}
