library sembast.io;

import 'package:sembast/sembast.dart';
import 'package:sembast/src/io/database_factory_io.dart' as database_io;

/// Factory for io databases (flutter, dart vm).
///
/// Each database is a file.
DatabaseFactory get databaseFactoryIo => database_io.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    database_io.createDatabaseFactoryIo(rootPath: rootPath);

/// deprecated.
@Deprecated('Use databaseFactoryIo instead')
DatabaseFactory get ioDatabaseFactory => databaseFactoryIo;
