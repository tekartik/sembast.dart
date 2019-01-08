## 1.13.0

* Add support for dotted fields, i.e. `'path.sub'` allow setting/getting/filtering/sorting on `path` inner value `sub`
 
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