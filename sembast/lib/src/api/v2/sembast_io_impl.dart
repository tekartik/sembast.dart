import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/io/database_factory_io.dart' as io;

/// File system based database factory (io).
DatabaseFactory get databaseFactoryIo => io.databaseFactoryIo;

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String rootPath}) =>
    io.createDatabaseFactoryIo(rootPath: rootPath);
