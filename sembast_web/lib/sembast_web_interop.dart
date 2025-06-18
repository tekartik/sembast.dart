import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/web_interop/sembast_web.dart' as src;

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWeb => src.databaseFactoryWeb;

/// Sembast factory for Web Workers.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWebWorker => src.databaseFactoryWebWorker;
