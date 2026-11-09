/// sembast for the Dart VM and Flutter Android, iOS, macOS, Windows and Linux.
///
/// Exports the whole `package:sembast/sembast.dart` API and
/// [databaseFactoryIo], which stores each database in a single file.
///
/// In a Flutter app, put the file in a folder from `path_provider`
/// (`getApplicationSupportDirectory()`). On the web, use
/// `package:sembast_web/sembast_web.dart` instead.
library;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/v2/sembast_io.dart' as database_io;

export 'sembast.dart';

/// Factory for io databases (flutter, dart vm).
///
/// Each database is a file: the path given to
/// [DatabaseFactory.openDatabase] is a file path, absolute or relative to the
/// current directory. Missing parent folders are created.
///
/// ```dart
/// var db = await databaseFactoryIo.openDatabase('my_app.db');
/// ```
///
/// In Flutter, use an absolute path in a folder of the app
/// (`package:path_provider` and `package:path`):
///
/// ```dart
/// var dir = await getApplicationSupportDirectory();
/// var db = await databaseFactoryIo.openDatabase(join(dir.path, 'my_app.db'));
/// ```
///
/// Open each database once and keep the [Database] for the lifetime of the
/// app. A database file must be used by one process and one isolate only
/// (`sembast_sqflite` is cross process safe).
///
/// Throws an [UnimplementedError] when used on the web: use
/// `databaseFactoryWeb` from `package:sembast_web` there.
DatabaseFactory get databaseFactoryIo => database_io.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
///
/// A relative path given to [DatabaseFactory.openDatabase] is then resolved
/// in [rootPath].
DatabaseFactory createDatabaseFactoryIo({String? rootPath}) =>
    database_io.createDatabaseFactoryIo(rootPath: rootPath);
