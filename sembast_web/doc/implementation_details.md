# Some implementation details

## Storage format

### Indexed DB

A sembast database is stored in one Indexed DB database that acts a journal database.
Like sembast, the whole database is loaded into memory from indexedDB.

The journal database allow building a consistent database at any time even across tabs.

## Synchronization between tabs

The journal database has a global auto-incremental revision number that is incremented for each change 
(one increment per transaction).

Sembast uses web `BroadcastChannel` to notify other tabs and workers about the lastest revision number of the database.

It also registers for `BroadcastChannel` messages to be notified when another tab makes some changes.
It then compares its current revision number vs the new one and reload
the new database changes if needed. Only the new/modified records are loaded, making changes across tabs efficient.