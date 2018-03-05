import 'package:sembast/sembast.dart';

class SembastDatabase extends Database {
  SembastDatabase(DatabaseStorage _storage) : super(_storage);

  @override
  // ignore: deprecated_member_use
  Transaction get transaction => super.transaction;

}