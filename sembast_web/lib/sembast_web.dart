/// sembast for the web and Flutter web (JavaScript and WebAssembly).
///
/// Exports the whole `package:sembast/sembast.dart` API and
/// [databaseFactoryWeb], which stores each database in IndexedDB. Only the
/// factory is web specific: stores, records, queries and transactions are
/// the sembast API.
///
/// ```dart
/// import 'package:sembast_web/sembast_web.dart';
///
/// Future<void> main() async {
///   // The name of the IndexedDB database, not a file path.
///   var db = await databaseFactoryWeb.openDatabase('my_app.db');
///   var store = intMapStoreFactory.store('animals');
///   var key = await store.add(db, {'name': 'cat'});
///   print(await store.record(key).get(db)); // {name: cat}
///   await db.close();
/// }
/// ```
library;

import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web_interop.dart' as src;

export 'package:sembast/sembast.dart';

/// Sembast factory for the Web.
///
/// Build on top of IndexedDB and BroadcastChannel.
///
/// The path given to [DatabaseFactory.openDatabase] is the IndexedDB
/// database name (no folder, no `path_provider`). Content is synchronized
/// across the open tabs and a transaction can run again when another tab
/// wrote at the same time, so keep transactions idempotent.
///
/// Throws an [UnimplementedError] when used outside the web: use
/// `databaseFactoryIo` from `package:sembast/sembast_io.dart` there. In a
/// Flutter app targeting both, test `kIsWeb` to pick the factory.
DatabaseFactory get databaseFactoryWeb => src.databaseFactoryWeb;

/// Sembast factory for Web Workers.
///
/// Build on top of IndexedDB and BroadcastChannel.
DatabaseFactory get databaseFactoryWebWorker => src.databaseFactoryWebWorker;
