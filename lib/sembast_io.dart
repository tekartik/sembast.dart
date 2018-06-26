library sembast.io;

import 'package:sembast/sembast.dart';

import 'src/io/io_database_factory.dart' as _;

DatabaseFactory get databaseFactoryIo => _.ioDatabaseFactory;

@deprecated
DatabaseFactory get ioDatabaseFactory => databaseFactoryIo;
