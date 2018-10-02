import 'package:sembast/src/io/io_file_system.dart';
import 'package:sembast/src/sembast_fs.dart';

/// Io file system implementation
class IoDatabaseFactory extends FsDatabaseFactory {
  // Use [ioDatabaseFactory] instead
  @deprecated
  IoDatabaseFactory() : super(ioFileSystem);
}

/// The factory
// ignore: deprecated_member_use
final IoDatabaseFactory ioDatabaseFactory = IoDatabaseFactory();
