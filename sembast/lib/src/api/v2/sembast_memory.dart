import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart' as memory;

/// In memory specialy database name, this database is always blank
/// only when used with `databaseFactoryMemory`
const sembastInMemoryDatabasePath = 'sembast://memory';

/// The in memory factory (no storage).
DatabaseFactory get databaseFactoryMemory => memory.databaseFactoryMemory;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryFs => memory.databaseFactoryMemoryFs;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryJdb => memory.databaseFactoryMemoryJdb;

/// Create a new empty factory
DatabaseFactory newDatabaseFactoryMemory() => memory.DatabaseFactoryMemory();

/// Open a memory database, always blank
Future<Database> openNewInMemoryDatabase({
  int? version,
  OnVersionChangedFunction? onVersionChanged,
  DatabaseMode? mode,
  SembastCodec? codec,
}) => databaseFactoryMemory.openDatabase(
  sembastInMemoryDatabasePath,
  version: version,
  mode: mode,
  codec: codec,
  onVersionChanged: onVersionChanged,
);
