library sembast.memory;

import 'sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart' as impl;

/// The factory
DatabaseFactory get databaseFactoryMemory => impl.databaseFactoryMemory;

// 2018-11-15 first deprecation @Deprecated('Use databaseFactoryMemory instead')
DatabaseFactory get memoryDatabaseFactory => databaseFactoryMemory;

/// The memory with a simulated file system factory
DatabaseFactory get databaseFactoryMemoryFs => impl.databaseFactoryMemoryFs;

// 2018-11-15 first deprecation @Deprecated('Use databaseFactoryMemoryFs instead')
DatabaseFactory get memoryFsDatabaseFactory => databaseFactoryMemoryFs;
