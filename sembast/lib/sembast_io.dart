library sembast.io;

import 'package:sembast/sembast.dart';

import 'package:sembast/src/io/database_factory_io.dart' as database_io;

DatabaseFactory get databaseFactoryIo => database_io.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    database_io.createDatabaseFactoryIo(rootPath: rootPath);

@Deprecated("Use dataFactoryIo instead")
DatabaseFactory get ioDatabaseFactory => databaseFactoryIo;
