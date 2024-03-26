import 'dart:async';

import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/protected/database.dart';
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

/// Database extension methods.
extension DatabaseExtension on Database {
  /// Compact the database.
  ///
  /// Behavior depends on the implementation. On sembast io, the file
  /// will be rewritten removing obsolete lines. On sembast_web
  /// and sembast_sqflite, history is purged.
  Future<void> compact() => (this as SembastDatabase).compact();

  /// Behavior depends on the implementation. On sembast io, nothing will happen.
  /// On sembast_web and sembast_sqflite, data will be
  /// read again (incrementally or not) to handle external changes.
  Future<void> checkForChanges() => (this as SembastDatabase).checkForChanges();
}
