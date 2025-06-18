import 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWeb => _stub(
  'databaseFactoryWeb not support on Flutter/VM. Use `sembast_sqflite` or `sembast` io implementation',
);

/// Sembast factory for Web Worker
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWebWorker => _stub(
  'databaseFactoryWebWorker not support on Flutter/VM. Use `sembast_sqflite` or `sembast` io implementation',
);
T _stub<T>(String message) {
  throw UnimplementedError(message);
}
