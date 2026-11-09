import 'package:sembast/src/api/v2/sembast.dart';
import 'package:sembast/src/memory/database_factory_memory.dart' as memory;

/// In memory specialy database name, this database is always blank
/// only when used with `databaseFactoryMemory`
const sembastInMemoryDatabasePath = 'sembast://memory';

/// The in memory factory (no storage).
///
/// A global factory: opening the same path twice gives the same database
/// until it is closed, and its content is lost when it is closed. For unit
/// tests, [newDatabaseFactoryMemory] gives a new empty factory per test.
DatabaseFactory get databaseFactoryMemory => memory.databaseFactoryMemory;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryFs => memory.databaseFactoryMemoryFs;

/// The memory with a simulated file system factory.
DatabaseFactory get databaseFactoryMemoryJdb => memory.databaseFactoryMemoryJdb;

/// Create a new empty factory
///
/// Nothing is saved. Use one per unit test so that tests do not share data:
///
/// ```dart
/// var db = await newDatabaseFactoryMemory().openDatabase('test.db');
/// ```
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
