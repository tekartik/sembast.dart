library sembast.io;

import 'src/io/io_file_system.dart';
import 'src/sembast_fs.dart';

/// The factory
// ignore: deprecated_member_use
final IoDatabaseFactory ioDatabaseFactory = new IoDatabaseFactory();

/// Io file system implementation
class IoDatabaseFactory extends FsDatabaseFactory {
  // Use [ioDatabaseFactory] instead
  @deprecated
  IoDatabaseFactory() : super(ioFileSystem);
}
