import 'package:sembast/src/api/v2/sembast.dart';

/// File system based database factory (io).
DatabaseFactory get databaseFactoryIo =>
    _stub('databaseFactoryIo not supported on the web. use `sembast_web`');

T _stub<T>(String message) {
  throw UnimplementedError(message);
}

/// Make sembast database all belong to a single rootPath instead of relative to
/// the current directory or absolute in the whole file system
DatabaseFactory createDatabaseFactoryIo({String? rootPath}) => _stub(
    'createDatabaseFactoryIo not supported on the web. use `sembast_web`');
