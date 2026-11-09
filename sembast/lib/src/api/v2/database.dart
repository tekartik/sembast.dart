import 'dart:async';

import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/protected/database.dart';
import 'package:sembast/src/api/transaction.dart';

export 'package:sembast/src/api/field.dart' show Field, FieldValue, FieldKey;

/// Database.
///
/// The database object and client for the store and record operations
///
/// Get it from [DatabaseFactory.openDatabase], once, and keep it for the
/// lifetime of the app. Pass it as the first argument of the store and record
/// methods (`store.add(db, value)`, `store.record(key).get(db)`). Inside
/// [transaction], pass the transaction instead.
abstract class Database implements DatabaseClient {
  /// Version of the database
  int get version;

  /// Database  path
  String get path;

  /// execute the action in a transaction
  /// use the current if any
  ///
  /// The changes are all committed when [action] completes, or none of them
  /// if it throws. Use the [Transaction] given to [action] for every call
  /// inside it: a write with this database waits for the transaction to end
  /// (deadlock).
  ///
  /// ```dart
  /// await db.transaction((txn) async {
  ///   await store.add(txn, {'name': 'cat'});
  ///   await store.add(txn, {'name': 'dog'});
  /// });
  /// ```
  Future<T> transaction<T>(
    FutureOr<T> Function(Transaction transaction) action,
  );

  /// Close the database
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

  /// Warning: unsafe.
  ///
  /// On sembast io, the file will be reloaded. Unpredictable behavior if a write
  /// happens at the same time. The database is closed and re-opened.
  /// So any pending listeners are lost.
  Future<void> reOpen() => (this as SembastDatabase).reOpen();

  /// Warning: unsafe.
  ///
  /// On sembast io, the file will be reloaded. Unpredictable behavior if a write
  /// happens at the same time. The database if not closed and existing listeners
  /// remain.
  Future<void> reload() => (this as SembastDatabase).reload();
}
