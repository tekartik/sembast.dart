import 'package:idb_shim/idb_client_native.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_web/src/jdb_import.dart';

/// The native jdb factory
var jdbFactoryIdbNative = JdbFactoryIdb(idbFactoryNative);

/// The sembast idb native factory
var databaseFactoryIdbNative = DatabaseFactoryJdb(jdbFactoryIdbNative);
