import 'dart:async';

import 'package:sembast/src/api/compat/database.dart';
import 'package:sembast/src/api/transaction.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;

export 'package:sembast/src/api/field.dart';

// ignore_for_file: deprecated_member_use_from_same_package

/// Database.
///
/// The database object and client for the store and record operations
abstract class Database extends DatabaseCompat implements v2.Database {
  /// Version of the database.
  @override
  int get version;

  /// Database path.
  @override
  String get path;

  /// Executes the action in a transaction.
  @override
  Future<T> transaction<T>(
      FutureOr<T> Function(Transaction transaction) action);

  /// Closes the database.
  @override
  Future close();
}

/// Callback interface called when the existing version differs from the
/// one expected.
///
/// Allow to perform migration or data change. Can return a future or not.
typedef OnVersionChangedFunction = FutureOr Function(
    Database db, int oldVersion, int newVersion);
