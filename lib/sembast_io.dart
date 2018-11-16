library sembast.io;

import 'package:sembast/sembast.dart';

import 'src/io/io_database_factory.dart' as _;

DatabaseFactory get databaseFactoryIo => _.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    _.createDatabaseFactoryIo(rootPath: rootPath);

@Deprecated("Use dataFactoryIo instead")
DatabaseFactory get ioDatabaseFactory => databaseFactoryIo;
