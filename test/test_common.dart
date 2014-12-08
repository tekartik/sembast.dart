library tekartik_iodb.database_test;

// basically same as the io runner but with extra output
import 'package:tekartik_iodb/database.dart';
import 'dart:async';

Future<Database> setupForTest(DatabaseFactory factory, String path) {
  return factory.deleteDatabase(path).then((_) {
    return factory.openDatabase(path);
  });
}
