import 'dart:async';

///
/// Storage implementation
///
/// where the database is read/written to if needed
///
abstract class DatabaseStorage {
  String get path;

  bool get supported;

  DatabaseStorage get tmpStorage;

  Future tmpRecover();

  Future delete();

  Future<bool> find();

  Future findOrCreate();

  Stream<String> readLines();

  Future appendLines(List<String> lines);

  Future appendLine(String line) => appendLines([line]);
}
