import 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWeb => _stub('databaseFactoryWeb');

/// Sembast factory for Web workers.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWebWorker =>
    _stub('databaseFactoryWebWorker');

T _stub<T>(String message) {
  throw UnimplementedError(message);
}
