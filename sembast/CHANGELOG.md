## 2.4.0-dev.3

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

* Enforce `Map<String, dynamic>` for maps in the store API
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