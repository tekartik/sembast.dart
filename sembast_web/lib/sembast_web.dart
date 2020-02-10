import 'package:sembast/sembast.dart';
import 'package:sembast_web/src/browser.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB.
DatabaseFactory get databaseFactoryWeb => databaseFactoryIdbNative;
