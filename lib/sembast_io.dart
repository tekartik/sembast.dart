library sembast.io;

import 'dart:async';

import 'sembast.dart';
import 'src/sembast_fs.dart';

import 'src/io/io_file_system.dart';

/// The factory
final IoDatabaseFactory ioDatabaseFactory = new IoDatabaseFactory();

/// Io file system implementation
class IoDatabaseFactory extends FsDatabaseFactory {
  IoDatabaseFactory() : super(ioFileSystem);
}

///
/// Use directly [IoDatabaseFactory.openDatabase]
/// @deprecated 2014-12 v 0.1.1
///
@deprecated
Future<Database> openIoDatabase(String path,
    {int version,
    OnVersionChangedFunction onVersionChanged,
    DatabaseMode mode: DatabaseMode.CREATE}) {
  return ioDatabaseFactory.openDatabase(path,
      version: version, onVersionChanged: onVersionChanged, mode: mode);
}
