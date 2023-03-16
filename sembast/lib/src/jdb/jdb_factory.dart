import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/protected/jdb.dart';

/// Jdb implementation.
abstract class JdbFactory {
  /// Open the database.
  Future<JdbDatabase> open(String path, DatabaseOpenOptions options);

  /// Delete a database
  Future<void> delete(String path);

  /// Check if a database exists
  Future<bool> exists(String path);
}
