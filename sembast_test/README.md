# sembast_test

The shared test suites of [sembast](https://pub.dev/packages/sembast): every
`DatabaseFactory` implementation (memory, io, sembast_web on IndexedDB,
sembast_sqflite, ...) runs the same tests, so they all behave the same. It
also holds the test helpers (`DatabaseTestContext`, `setupForTest`, `reOpen`)
and demonstration codecs.

## Getting started

Not on pub.dev. Add it to the `dev_dependencies` of the package that provides
the factory (default branch, no `ref:`):

```yaml
dev_dependencies:
  test: ">=1.31.0"
  sembast_test:
    git:
      url: https://github.com/tekartik/sembast.dart
      path: sembast_test
```

Then one test file runs the main suite on your factory:

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_test/all_test.dart' as all_test;
import 'package:sembast_test/test_common.dart';

void main() {
  // Replace by the factory under test.
  var ctx = DatabaseTestContext()..factory = newDatabaseFactoryMemory();
  group('my_factory', () {
    all_test.defineTests(ctx);
  });
}
```

`dart test` runs it on the VM; a web factory goes in a `@TestOn('browser')`
file run with `dart test -p chrome` (add `-c dart2js,dart2wasm`, or a
`compilers:` list in `dart_test.yaml`, to run both compilers).

## Entry points

* `all_test.dart` `defineTests(DatabaseTestContext)`: the main suite (crud,
  find, query, transactions, listeners, open and upgrades, codecs,
  import/export).
* `all_jdb_test.dart` `defineJdbTests(DatabaseTestContextJdb)`: journal
  backends (`DatabaseFactoryJdb`: sembast_web, sembast_sqflite, idb_shim),
  format, codec and two instances on the same database.
* `all_fs_test.dart` `defineTests(DatabaseTestContextFs)`: the file format
  (`DatabaseFactoryFs`), `all_io_test.dart` `allIoGroup(...)`: io
  import/export (VM only).

## Who runs it

| Implementation | Runner |
|---|---|
| memory, memory fs, memory jdb | `sembast_test/test/multiplatform` |
| io | `sembast_test/test/io_factory_test.dart` |
| jdb on idb_shim (memory, io, native IndexedDB) | `sembast_test/test` and `test/web` |
| sembast_sqflite | `sembast_sqflite_common_test` (sqflite ffi) |
| jdb on `idb_shim_html_compat` | `idb_shim_more` `sembast_web_html_compat` |

## Writing a shared test

* Use `setupForTest(ctx, name)` / `dbPathFromName(name)`: databases under
  `.dart_tool/sembast/test/`, deleted first.
* A test must be able to fail: put `fail('should fail')` after a call that
  must throw and catch only the expected type; never leave a check disabled
  (`if (false)`) because one implementation fails it: skip the test there
  with the reason.
* A broken implementation must fail fast: bounded loops, a `timeout:` on slow
  tests, wait for an event rather than a fixed delay.

More: the `sembast-test-setup` skill
(`skills/sembast-test-setup/SKILL.md`).
