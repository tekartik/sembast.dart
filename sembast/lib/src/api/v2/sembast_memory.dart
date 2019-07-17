import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart' as memory;

/// The in memory factory (no storage).
DatabaseFactory get databaseFactoryMemory => memory.databaseFactoryMemory;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryFs => memory.databaseFactoryMemoryFs;
