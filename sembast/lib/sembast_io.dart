library;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/v2/sembast_io.dart' as database_io;

export 'sembast.dart';

/// Factory for io databases (flutter, dart vm).
///
/// Each database is a file.
DatabaseFactory get databaseFactoryIo => database_io.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String? rootPath}) =>
    database_io.createDatabaseFactoryIo(rootPath: rootPath);
