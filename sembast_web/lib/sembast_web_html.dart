import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web_interop.dart' as src;

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and localStorage.
@Deprecated('Use databaseFactoryWeb from sembast_web.dart')
DatabaseFactory get databaseFactoryWeb => src.databaseFactoryWeb;
