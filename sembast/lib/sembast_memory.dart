/// sembast in memory, for unit tests and temporary data.
///
/// Exports the whole `package:sembast/sembast.dart` API and the memory
/// factories: [newDatabaseFactoryMemory] (a new empty factory, best for each
/// test), [databaseFactoryMemory] (a global one) and
/// [openNewInMemoryDatabase]. Nothing is saved.
library;

export 'package:sembast/src/api/v2/sembast_memory.dart'
    show
        sembastInMemoryDatabasePath,
        databaseFactoryMemory,
        databaseFactoryMemoryFs,
        newDatabaseFactoryMemory,
        openNewInMemoryDatabase;

export 'sembast.dart';
