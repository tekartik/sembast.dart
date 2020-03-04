@deprecated
library sembast.api.compat.v1.memory;

import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';

// 2018-11-15 first deprecation @Deprecated('Use databaseFactoryMemory instead')
/// @deprecated v2
@deprecated
DatabaseFactory get memoryDatabaseFactory => databaseFactoryMemory;

// 2018-11-15 first deprecation @Deprecated('Use databaseFactoryMemoryFs instead')
/// @deprecated v2
@deprecated
DatabaseFactory get memoryFsDatabaseFactory => databaseFactoryMemoryFs;
