import 'dart:async';

///
/// Storage implementation
///
/// where the database is read/written to if needed
///
abstract class DatabaseStorage {
  /// the storage path.
  String get path;

  /// true if supported.
  bool get supported;

  /// Tmp storage used.
  DatabaseStorage get tmpStorage;

  /// Recover from a temp file.
  Future tmpRecover();

  /// Delete the storage.
  Future delete();

  /// returns true if the storage exists.
  Future<bool> find();

  /// Create the storage if needed
  Future findOrCreate();

  /// Read all lines.
  Stream<String> readLines();

  /// Append multiple lines.
  Future appendLines(List<String> lines);

  /// Append one line
  Future appendLine(String line) => appendLines([line]);
}
