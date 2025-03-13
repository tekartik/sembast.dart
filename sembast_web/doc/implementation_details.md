# Some implementation details

## Storage format

### Indexed DB

The whole database is store in one Indexed DB database that acts a journal database.
Like sembast, the whole database is loaded into memory from indexedDB.

Each record in the journal database allow building a consistent database at any time even across tabs.

## Synchronization between tabs

The journal database has a global auto-incremental revision number that is incremented for each change 
(one increment per transaction).

Sembast uses web `LocalStorage` to store the lastest version num of the database.

It also registers for `LocalStorage` changes to be notified when another tab makes some changes.
It then compare its current revision number vs the new one and reload
the new database changes if needed. Only the new/modified records are loaded, making changes across tabs efficient.