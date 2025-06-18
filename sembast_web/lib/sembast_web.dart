import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web_interop.dart' as src;

export 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and BroadcastChannel.
DatabaseFactory get databaseFactoryWeb => src.databaseFactoryWeb;

/// Sembast factory for Web Workers.
///
/// Build on top of IndexedDB and BroadcastChannel.
DatabaseFactory get databaseFactoryWebWorker => src.databaseFactoryWebWorker;
