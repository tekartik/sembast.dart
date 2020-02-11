import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/browser.dart' as src;

export 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
DatabaseFactory get databaseFactoryWeb => src.databaseFactoryWeb;
