## 2.4.7

* Requires sembast 3.10.1 (cross tab fixes: listeners after a full reload by
  `checkForChanges`, an upgrade retried after another tab wrote saves its
  version)
* Documentation: codecs are supported, pitfalls (ints above 2^53, delete
  while another tab has the database open), implementation details fixed

## 2.4.6+2

* Documentation: setup with `pub add`, one code base with sembast io (`kIsWeb` or conditional
  import), example without idb_shim, dartdoc, skill updated
* Add `sembast-web-setup` agent skill in `skills/`, installable with `dart run skills@ get`

## 2.4.5+1

* Requires dart 3.12

# 2.4.4+1

* Move core jdb implementation to idb_shim
* Fixes #408

# 2.4.3

* Deps update
* requires Dart 3.10
* Export jdb support

## 2.4.2

* Add `databaseFactoryWebWorker` to support web workers.
* Use `BroadcastChannel` to support cross-tab/workers notifications.

## 2.4.1

* Requires dart 3.7

## 2.4.0+4

* Remove legacy html support.

## 2.3.0+1

* web and js_interop (for wasm) support

## 2.2.0

* Dart 3 only

## 2.1.3

* Dart 3 support

## 2.1.2

* Bump sembast dependency.

## 2.1.1

* Add async codec support.

## 2.1.0+4

* Support strict-casts mode

## 2.0.1+1

* dart 2.14 lints support

## 2.0.0+2

*`nnbd` support, breaking change.

## 1.2.0+1

* Bump sembast dependency
* Improve int key generation (through sembast update)

## 1.1.0+1

* Add Blob and Timestamp support
* Allow importing `sembast_web.dart` in non-web app.

## 1.0.0

* First stable version

## 0.2.0+1

*Support cross-tab transactions and updates.

## 0.1.0+4

* Initial version, experimental
