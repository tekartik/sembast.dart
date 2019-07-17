@TestOn('vm')
library sembast.test.compat.exp_io_test;

// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:path/path.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

import 'test_common.dart';

void main() {
  group('exp_io', () {
    test('openHelper', () async {
      String dbPath = join('.dart_tool', 'sembast', 'test', 'open_helper.db');

      // Make openHelper a singleton
      var openHelper = OpenHelper(dbPath);

      // Get the database in a safe way
      var db = await openHelper.getDatabase();
      await db.put('value', 'key');

      var db1 = await openHelper.getDatabase();
      var db2 = await openHelper.getDatabase();

      expect(db1, db2);

      await db1.close();
    });
  });
}

///
/// Helper to open a single instance of a database
/// This should be a global or singleton
///
class OpenHelper {
  final String path;
  Database _db;
  Completer<Database> _completer;

  OpenHelper(this.path);

  /// Get the opened database
  Future<Database> getDatabase() async {
    if (_completer == null) {
      _completer = Completer();
      await _openDatabase();
    }
    return _completer.future;
  }

  Future<Database> _openDatabase() async {
    _db = await databaseFactoryIo.openDatabase(path);
    // Mark as opened
    _completer.complete(_db);
    return _db;
  }
}
