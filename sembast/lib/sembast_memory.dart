library sembast.memory;

import 'package:sembast/src/memory/database_factory_memory.dart' as impl;

import 'sembast.dart';

/// The in memory factory (no storage).
DatabaseFactory get databaseFactoryMemory => impl.databaseFactoryMemory;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryFs => impl.databaseFactoryMemoryFs;
