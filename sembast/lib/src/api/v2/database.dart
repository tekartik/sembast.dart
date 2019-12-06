import 'dart:async';

import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/transaction.dart';

export 'package:sembast/src/api/field.dart';

/// Database.
///
/// The database object and client for the store and record operations
abstract class Database implements DatabaseClient {
  /// Version of the database
  int get version;

  /// Database  path
  String get path;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future<T> transaction<T>(
      FutureOr<T> Function(Transaction transaction) action);

  ///
  /// Close the database
  ///
  Future close();
}
