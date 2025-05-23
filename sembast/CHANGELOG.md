## 3.8.5+1

* Add `Filter.arrayContains`, `Filter.arrayContainsAny`, `Filter.arrayContainsAll` to filter on list content.
* Update minimum `meta` version to 1.14.0

## 3.8.4+1

* Requires Dart 3.7

## 3.8.3

* Requires Dart 3.6
* Add `QueryRef.delete()` to delete all matching records.

## 3.8.2

* Add `openNewInMemoryDatabase()` helper to open a new in-memory database, always empty.

## 3.8.1+1

* Add experimental onAllStore listeners (not typed) `Database.addAllStoresChangesListener` and `Database.removeAllStoresChangesListener`
* Add `DatabaseClient.dropAll()` to drop all existing stores and folders.
* Make exception constants const.

## 3.8.0+1

* Add `Query.getKey`, `Query.getKeys`,  `Query.onKey`, `Query.onKeys`,
  `Query.getKeySync`, `Query.getKeysSync`, `Query.onKeysSync`, `Query.onKeySync` methods
* Export json helpers from `utils/type_adapters.dart`

## 3.7.5+2

* Add `Timestamp.addDuration()` and `Timestamp.substractDuraction()`
* Add `Timestamp.difference()` and `Timestamp.zero`

## 3.7.4+3

* Add `DatabaseFactory.databaseExists(String path)` to check if a database exists.

## 3.7.3+3

* Add experimental `Database.reload()` to force reloading the database from the storage.
* Improve memory usage by caching the record list and avoiding too many casts.
* Fix notifyListener runtime issue observed on the web using wasm.
* Improve `compact` memory usage in sembast_io.

## 3.7.2

* Add `ifNotExists` options to `RecordRef.put()` to only create a record if does not exist.

## 3.7.1+3

* Add `Database.checkForChanges()` helper to force loading data
  shared between multiple jdb (web/sqflite) instances.

## 3.7.0

* Remove dependency on `dart:html`

## 3.6.0

* Add `RecordRef.onSnapshotSync`, `RecordsRef.onSnapshotsSync`, `QueryRef.onSnapshotsSync`, `QueryRef.onSnapshotSync`,
  `QueryRef.onCountSync` synchronous API extension where the first value is emitted synchronously.

## 3.5.1-1

* Add io export utils (mainly for tests)

## 3.5.0+1

* Dart 3 only
* Export `SembastTypeAdapter`, `JsonEncodableCodec`, `JsonEncodableEncoder` and
  `JsonEncodableDecoder` from `utils/type_adapter.dart`

## 3.4.9

* Add APIs `QueryRef.count()`, `QueryRef.onCount()`.
* Add synchronous version for all read APIs: `StoreRef.countSync()`,
  `StoreRef.findKeysSync()`, `StoreRef.findKeySync()`, `StoreRef.findSync()`,
  `StoreRef.findFirstSync()`, `QueryRef.countSync()`, `QueryRef.getSnapshotsSync()`,
  `QueryRef.getSnapshotSync()`.

## 3.4.8

* Add `RecordRef.getSync()`, `RecordRef.getSnapshotSync()`, `RecordRef.existsSync()` synchronous API extension.
* Add `RecordsRef.getSync()`, `RecordsRef.getSnapshotSync()` synchronous API extension.
* Add `RecordsRef.onSnapshots()` watcher extension.
* Add `valuesCompare()` in `utils.value_utils.dart` to compare values.

## 3.4.7

* Export 'Database.compact()' as a class extension.

## 3.4.6+1

* Add `SortOrder.custom` to allow custom sort order comparison function.
* Export `generateStringKey` in new `key_utils.dart`

## 3.4.5

* Fix store/record change listener timing, now triggered before the end of the transaction callback.

## 3.4.4

* Dart 3 support

## 3.4.3+1

* add `exportDatabaseLines`, `exportDatabaseLines`, `importDatabaseAny`
* Fix async codec support issues.

## 3.4.2

* Add async codec support.

## 3.4.1+1

* allow accessing an inner list item using a part index (such as `list.0`) and inner map in list (such as `list.0.tag`).
* Filter.equals/matches also support the wildcard `@` to look for any item in a list.

## 3.4.0+6

* Support strict-casts.
* add `generateIntKey` on StoreRef

## 3.3.1+1

* Add `StoreRef.generateKey()` to generate a unique key
* Fix export with disabled cooperator

## 3.3.0

* Add `StoreRef.onCount` to track filter count changes.

## 3.2.0+1

* Delete obsolete jdb records on open
* Requires dart 2.16

## 3.1.2

* Add support for list and maps in Filter.equals and Filter.notEquals

## 3.1.1+1

* dart 2.14 lints support
* Fix onChanges failing to store added records on jdb storage.

## 3.1.0+2

* Add `StoreRef.addOnChangesListener` and `StoreRef.removeOnChangesListener` to allow
  tracking changes in transactions.

## 3.0.4

* Add `databaseMerge` utility to merge records from an existing database.

## 3.0.3

* Add `Filter.not` filter for inverting a filter behavior.

## 3.0.2

* Fix cooperator so that concurrent sembast access properly pause.

## 3.0.1

* Add optional `storeNames` to `exportDatabase` and `importDatabase`

## 3.0.0+6

* `nnbd` support, breaking change.
* No longer supports null record value.

## 2.4.10+3

* Add `QueryRef.onSnapshot` to listen for the first matching record
* Fix dropped store issue in a transaction

## 2.4.9

* Add `utils/database_utils.dart`. `getNonEmptyStoreNames(db)` added.

## 2.4.8+1

* Clear mode existing/empty flag upon open to handle re-open.
* Handle corrupted utf8 lines in sembast io
* Improve int/string key generation during a transaction for jdb (i.e. for sembast_web)
* Improve listeners
* Fix `QueryRef.onSnapshots` initial order
* Add `newDatabaseFactoryMemory()` function to create a blank factory (for unit tests) 

## 2.4.6+1

* Optimize cooperator delay for the web and allow custom values for delay and pause.
* Fix listener for imported data during transaction (sembast_web and sembast_sqflite)

## 2.4.5

* Fix version handling when an error is thrown during open.

## 2.4.4+4

* Add support for filter operator & and |
* Allow importing `sembast_io.dart` in non-io app.
* Optimize query without sort orders.
* Optimize count without sort filter.

## 2.4.3

* Export `disableSembastCooperator()` for unit tests.
* Store and record database access now implemented as extensions.

## 2.4.2

* Fix finder start end of list issue

## 2.4.1+1

* Allow importing a database export using a codec
* Fix export for custom types

## 2.4.0

* Add Blob and Timestamp support

## 2.3.0

* Remove 1.x deprecated APIs

## 2.2.0+1

* Support for `sembast_web`

## 2.1.3

* Export `cloneValue` and `cloneList` from `utils/value_utils.dart`

## 2.1.2+3

* Pedantic 1.9 support
* Fix `Store.drop` behavior
* Fix listener behavior when no listener is attached 

## 2.1.1

* Add `RecordsRef.add` to `RecordsRef.update` to insert/update multiple records. 

## 2.1.0+1

* Add code documentation, code coverage and build badges

## 2.1.0

* Remove `logging` dependency

## 2.0.1+2

* Add `RecordRef.add` to insert a record if it does not exist.
* **BREAKING CHANGE** `RecordsRef.put` returns the list of values not the list of keys

## 2.0.0+1

* No change. Currently deprecated APIs will be removed.

## 1.19.0-dev.3

* Deprecated old APIs

## 1.17.2+2

* Add `QueryRef.getSnapshot`
* **BREAKING CHANGE** `RecordRef.put` returns the value not the key

## 1.17.1

* Add `StoreRef.addAll`

## 1.17.0

* Sdk 2.5.0 support

## 1.16.0+3

* Add record and query change tracking
* Fix `onVersionChanged` hangs if compact is triggered

## 1.15.4+1

* Fix inner map merging when updating a record

## 1.15.3

* Enforce `Map<String, Object?>` for maps in the store API
* Add `cloneMap` utility to allow modifying a read record

## 1.15.2

* Add the ability to escape keys with dot in their names for updates and queries (filter, sort)
* Fix codec signature check to compare the decrypted value instead of the encrypted one

## 1.15.1

* Add custom filter support and allow filtering on list content for `Filter.equals` and `Filter.matches`

## 1.15.0

* Add new API to allow strict typing on keys and values

## 1.14.0

* Make the database work in `cooperate` mode to avoid stuttering with big databases on Flutter
* Commit changes lazily to the storage

## 1.13.3

* Add support for user-defined codec to allow encryption

## 1.13.0

* Add support for nested dotted fields, i.e. `'path.sub'` allow setting/getting/filtering/sorting on `path` 
inner value `sub`
* support for boundaries (`start` and `end`) in a query with sort orders
 
## 1.12.0

* Add `Filter.matchs` for regular expression filtering
* Add `rootPath` support for `DatabaseFactoryIo` to allow relative path to a root folder

## 1.10.1

* Add `update` method to allow updating partially a Map record
* Add `updateRecords` utility methods to update multiple records based on a a filter
* properly clone each value when written and read

## 1.9.5

* Fix database manipulation issues during onVersionChanged

## 1.9.4

* Add value_utils to help comparing value and arrays

## 1.9.1

* New transaction API
* dart2 only

## 1.8.0

* fix flutter cast issue
* fix limit/offset implementation
* Update synchronized dependency
* make all constants lowercase

## 1.7.0

* mode `databaseModeNeverFails` is the new default
* API cleanup and add deprecations

## 1.6.1

* Add `implicit-cast: false` support

## 1.6.0

* Add bool support <https://github.com/tekartik/sembast.dart/pull/4>

## 1.5.0

* Update synchronized dependency
* Add DatabaseMode.NEVER_FAILS that will ignore the file once a corrupted record is encountered

## 1.3.9

* Add web example to test ddc support
* Fix transaction

## 1.3.7

* Strong mode support 
* support for setting record field directly
* fix support for dart 1.24

## 1.3.1

* Add support for import/export

## 1.2.2

* Add for support for isNull and notNull filter
* Add for support for sorting null last
* Travis test integration

## 1.0.0

* Initial revision 