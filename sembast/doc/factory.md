# What is sembast database factory

A factory is a concept I mainly got from the java world. It becomes the main entry point to the library, i.e. a
sembast `DatabaseFactory` allows you to open and delete a database.

Typically you would use a single factory in your application depending on the target (mobile, web, desktop), the factory
might be different.

By default sembast has a `databaseFactoryMemory` which does not persists data and a basic `databaseFactoryIo`
implemented on top of a file system (mobile, desktop, DartVM)
using a basic json file implementation (which is not cross process safe, i.e. if 2 applications write on the same
database, you might loose data).

Obviously this does not work with persistence on the web, so the package `sembast_web` exposes
`databaseFactoryWeb` that works on top of indexed_db and that is cross-tab safe.

On IO application (flutter web/mobile, DartVM), my recommendation is to use `sembast_sqflite`
which implements sembast on top of sqflite which is cross process safe (i.e. no corruption).

The flutter git project [tekartik_app_sembast](https://github.com/tekartik/app_flutter_utils.dart/tree/master/app_sembast) 
proposes any opiniated implementation for a getting the proper factory on all platforms
using a `getDatabaseFactory()` exported method (i.e. it will use `sembast_web` on the web, and `sembast_sqflite` for Mobile/Desktop).
The implementation is available as an example, you might decide for a different database location on the desktop using
`path_provider` package.
