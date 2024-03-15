import 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWeb => _stub('databaseFactoryWeb');

T _stub<T>(String message) {
  throw UnimplementedError(message);
}
