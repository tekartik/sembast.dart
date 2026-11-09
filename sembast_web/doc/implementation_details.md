# Some implementation details

## Storage format

### Indexed DB

A sembast database is stored in one Indexed DB database (of the same name) that acts a journal database, with two
object stores:

* `entry`: one entry per record (auto-incremented id, store name, record key, value, or a deleted mark). Writing a
  record replaces its previous entry, so the store holds the last state of each record.
* `info`: the revision (the id of the last entry written), the database meta (version, codec signature) and, after a
  compaction, the delta min revision.

Like sembast, the whole database is loaded into memory from indexedDB.

The journal database allow building a consistent database at any time even across tabs.

## Synchronization between tabs

The revision of the journal database is the id of the last entry written: it grows by one for each record written
(a transaction writing 3 records adds 3).

Sembast uses web `BroadcastChannel` to notify other tabs and workers about the lastest revision number of the database.

It also registers for `BroadcastChannel` messages to be notified when another tab makes some changes.
It then compares its current revision number vs the new one and reload
the new database changes if needed. Only the new/modified records are loaded, making changes across tabs efficient.

A write is only committed if the revision in IndexedDB is still the one the tab knows: otherwise the tab loads the
changes and runs the transaction again (keep transactions idempotent).

The entries of deleted records are removed by a compaction (at open when there are some, or `db.compact()`), which
sets the delta min revision. A
tab whose revision is below it can no longer load only the changes: it reloads the whole database (its listeners are
notified, sembast 3.10.1).

## Database helpers

* `databaseExists(name)` opens the IndexedDB database to look for the meta: when no such database exists, it creates
  an empty one (visible in the browser developer tools) and returns `false`.
* `deleteDatabase(name)` is an IndexedDB delete request: it waits until every connection to that database is closed,
  so it does not complete while another tab has the database open.
