// ignore_for_file: public_member_api_docs

import 'package:sembast/sembast.dart' show Database;

/// a class for using composition, i.e. handling multiple sembast dbs
abstract class Wrapper {
  final Database db;
  const Wrapper(this.db);
}
