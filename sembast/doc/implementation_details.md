# Some implementation details

## Storage format

### IO file

The whole database is store in one file where changes are appended (and sometimes the file is compacted to remove old records).

See sembast simple [io implementation](storage_format.md)

The implementation is for single process/single isolate VM/Flutter application although `sembast_sqflite` should be considered in Flutter.

### Journal database

Sembast can also use a journal database instead of a plain file.

Each record in the journal database allow building a consistent database at any time even across processes.

* [sembast_sqflite](https://pub.dev/packages/sembast_sqflite) to use a cross process/isolate safe storage on VM/Flutter application
* [sembast_web](https://pub.dev/packages/sembast_web) to use a cross tab safe storage on Web/Flutter Web 

## Record encoding

For IO/sqflite, records are saved as json entity.
For the web, records are saved as indexedDB records.

Sembast supports data encoding using [codec](codec.md) including support for custom types.

## Cooperator

Sembast uses what I call a cooperator. It will pause (awaiting) for 100 microseconds every 4 ms
for every heavy algorithm (sorting, filtering).

This was done when testing on flutter with 10K+ records. On some devices, the UI
was blocked when sorting and filtering was done.

It is not perfect but running in a separate isolate would have impacted performance
a lot so it is partial solution for cooperating in a single-thread world.