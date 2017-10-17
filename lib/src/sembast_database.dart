part of sembast;

class Database {
  static Logger logger = new Logger("Sembast");
  final bool LOGV = logger.isLoggable(Level.FINEST);

  final DatabaseStorage _storage;
  final SynchronizedLock lock = new SynchronizedLock();

  String get path => _storage.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;

  _Meta _meta;
  int get version => _meta.version;

  bool _opened = false;
  DatabaseMode _openMode;

  Store get mainStore => _mainStore;

  Store _mainStore;
  Map<String, Store> _stores = new Map();

  Iterable<Store> get stores => _stores.values;

  Database([this._storage]);

  // not used
  @deprecated
  Future onUpgrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  // not used
  @deprecated
  Future onDowngrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  ///
  /// put a value in the main store
  ///
  Future put(var value, [var key]) {
    return _mainStore.put(value, key);
  }

  void _clearTxnData() {
// remove temp data in all store
    for (Store store in stores) {
      store._rollback();
    }
  }

  void rollback() {
    // only valid in a transaction
    if (!_inTransaction) {
      throw new Exception("not in transaction");
    }
    _clearTxnData();
  }

  bool get _inTransaction => lock.inZone;

  Transaction _transaction;

  //@Deprecated("don't use")
  Transaction get transaction => _transaction;

  ///
  /// execute the action in a transaction
  /// use the current if any
  ///
  Future inTransaction(action()) {
    //devPrint("z: ${Zone.current[_zoneRootKey]}");
    //devPrint("z: ${Zone.current[_zoneChildKey]}");

    if (lock.inZone) {
      return lock.synchronized(action);
    }
    // delay first action
    return new Future(() {
      return lock.synchronized(() async {
        // Compatibility add transaction
        _transaction = new Transaction._(++_txnId);

        _transactionCleanUp() {
          // Mark transaction complete, ignore error
          _transaction._completer.complete();

          // Compatibility remove transaction
          _transaction = null;
        }

        var actionResult;
        try {
          actionResult = await new Future.sync(action);
          await _commit();
        } catch (e) {
          _clearTxnData();
          _transactionCleanUp();
          rethrow;
        }

        _clearTxnData();

        // the transaction is done
        // need compact?
        if (_storage.supported) {
          if (_needCompact) {
            await compact();
            //print(_exportStat.toJson());
          }
        }

        _transactionCleanUp();

        return actionResult;
      });
    });
  }

  bool _setRecordInMemory(Record record) {
    return record.store._setRecordInMemory(record);
  }

  void _loadRecord(Record record) {
    record.store._loadRecord(record);
  }

  ///
  /// Compact the database (work in progress)
  ///
  Future compact() {
    return lock.synchronized(() async {
      if (_storage.supported) {
        DatabaseStorage tmpStorage = _storage.tmpStorage;
        // new stat with compact + 1
        DatabaseExportStat exportStat = new DatabaseExportStat()
          ..compactCount = _exportStat.compactCount + 1;
        await tmpStorage.delete();
        await tmpStorage.findOrCreate();

        List<String> lines = [];
        _addLine(Map map) {
          var encoded;
          try {
            encoded = JSON.encode(map);
          } catch (e, st) {
            // usefull for debugging...
            print(map);
            print(e);
            print(st);
            rethrow;
          }
          exportStat.lineCount++;
          lines.add(encoded);
        }

        _addLine(_meta.toMap());
        for (Store store in stores) {
          for (Record record in store._records.values) {
            _addLine(record._toMap());
          }
        }
        await tmpStorage.appendLines(lines);
        await _storage.tmpRecover();
        /*
        print(_storage.toString());
        await _storage.readLines().forEach((String line) {
          print(line);
        });
        */
        _exportStat = exportStat;
      }
    });
  }

  // future or not
  _commit() async {
    List<Record> txnRecords = [];
    for (Store store in stores) {
      if (store._txnRecords != null) {
        txnRecords.addAll(store._txnRecords.values);
      }
    }

    // end of commit
    _saveInMemory() {
      for (Record record in txnRecords) {
        bool exists = _setRecordInMemory(record);
        // Try to estimated if compact will be needed
        if (_storage.supported) {
          if (exists) {
            _exportStat.obsoleteLineCount++;
          }
          _exportStat.lineCount++;
        }
      }
    }

    if (_storage.supported) {
      if (txnRecords.isNotEmpty) {
        List<String> lines = [];

        // writable record
        for (Record record in txnRecords) {
          Map map = record._toMap();
          var encoded;
          try {
            encoded = JSON.encode(map);
          } catch (e, st) {
            print(map);
            print(e);
            print(st);
            rethrow;
          }
          lines.add(encoded);
        }
        await _storage.appendLines(lines);
        _saveInMemory();
      }
    } else {
      _saveInMemory();
    }
  }

  /// clone and fix the store
  Record _cloneAndFix(Record record) {
    Store store = record.store;
    if (store == null) {
      store = mainStore;
    }
    return record._clone(store: store);
  }

  ///
  /// Put a record
  ///
  Future<Record> putRecord(Record record) {
    return inTransaction(() {
      return _putRecord(_cloneAndFix(record));
    }) as Future<Record>;
  }

  ///
  /// Get a record by its key
  ///
  Future<Record> getRecord(var key) {
    return mainStore.getRecord(key);
  }

  ///
  /// Get a store record
  ///
  Future<Record> getStoreRecord(Store store, var key) {
    return store.getRecord(key);
  }

  ///
  /// Put a list or records
  ///
  Future<List<Record>> putRecords(List<Record> records) {
    return inTransaction(() {
      List<Record> toPut = [];
      for (Record record in records) {
        toPut.add(_cloneAndFix(record));
      }
      return _putRecords(toPut);
    }) as Future<List<Record>>;
  }

  ///
  /// find records in the main store
  ///
  Future<List<Record>> findRecords(Finder finder) {
    return mainStore.findRecords(finder);
  }

  ///
  /// find records in the given [store]
  ///
  Future<List<Record>> findStoreRecords(Store store, Finder finder) {
    return store.findRecords(finder);
  }

  Record _putRecord(Record record) {
    return record.store._putRecord(record);
  }

  // record must have been clone before
  List<Record> _putRecords(List<Record> records) {
    // temp records
    for (Record record in records) {
      _putRecord(record);
    }
    return records;
  }

  ///
  /// get a value by key in the main store
  ///
  Future get(var key) {
    return _mainStore.get(key);
  }

  ///
  /// count all records in the main store
  ///
  Future<int> count() {
    return _mainStore.count();
  }

  ///
  /// delete a record by key in the main store
  ///
  Future delete(var key) {
    return _mainStore.delete(key);
  }

  ///
  /// delete a [record]
  ///
  Future deleteRecord(Record record) {
    return record.store.delete(record.key);
  }

  ///
  /// delete a record by key in the main store
  ///
  Future deleteStoreRecord(Store store, var key) {
    return store.delete(key);
  }

  bool _hasRecord(Record record) {
    return record.store._has(record.key);
  }

  ///
  /// reload
  //
  Future reOpen(
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {
    return lock.synchronized(() {
      close();
      // Reuse same open mode unless specified
      return open(
          version: version, onVersionChanged: onVersionChanged, mode: mode ?? this._openMode);
    });

  }

  void _checkMainStore() {
    if (_mainStore == null) {
      _addStore(null);
    }
  }

  Store _addStore(String storeName) {
    if (storeName == null) {
      return _mainStore = _addStore(_main_store);
    } else {
      Store store = new Store._(this, storeName);
      _stores[storeName] = store;
      return store;
    }
  }

  ///
  /// find existing store
  ///
  Store findStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
    }
    return store;
  }

  ///
  /// get or create a store
  /// an empty store will not be persistent
  ///
  Store getStore(String storeName) {
    Store store;
    if (storeName == null) {
      store = _mainStore;
    } else {
      store = _stores[storeName];
      if (store == null) {
        store = _addStore(storeName);
      }
    }
    return store;
  }

  ///
  /// clear and delete a store
  ///
  Future deleteStore(String storeName) {
    Store store = findStore(storeName);
    if (store == null) {
      return new Future.value();
    } else {
      return store.clear().then((_) {
        // do not delete main
        if (store != mainStore) {
          _stores.remove(storeName);
        }
      });
    }
  }

  ///
  /// open a database
  ///
  Future<Database> open(
      {int version,
      OnVersionChangedFunction onVersionChanged,
      DatabaseMode mode}) {

    // Default mode
    _openMode = mode ??= DatabaseMode.CREATE;

    if (_opened) {
      if (path != this.path) {
        throw new DatabaseException.badParam(
            "existing path ${this.path} differ from open path ${path}");
      }
      return new Future.value(this);
    }

    return lock.synchronized(() async {
      _Meta meta;

      Future _handleVersionChanged(int oldVersion, int newVersion) async {
        var result;
        if (onVersionChanged != null) {
          result = onVersionChanged(this, oldVersion, newVersion);
        }
        meta = new _Meta(newVersion);

        if (_storage.supported) {
          await _storage.appendLine(JSON.encode(meta.toMap()));
          _exportStat.lineCount++;
        }

        return result;
      }

      Future _openDone() async {
        // make sure mainStore is created
        _checkMainStore();

        // Set current meta
        // so that it is an old value during onVersionChanged
        if (meta == null) {
          meta = new _Meta(0);
        }
        if (_meta == null) {
          _meta = meta;
        }

        bool needVersionChanged = false;

        int oldVersion = meta.version;

        if (oldVersion == 0) {
          needVersionChanged = true;

          // Make version 1 by default
          if (version == null) {
            version = 1;
          }
          meta = new _Meta(version);
        } else {
          // no specific version requested or same
          if ((version != null) && (version != oldVersion)) {
            needVersionChanged = true;
          }
        }

        // mark it opened
        _opened = true;

        if (needVersionChanged) {
          await _handleVersionChanged(oldVersion, version);
        }
        _meta = meta;
        return this;
      }

      //_path = path;
      Future _findOrCreate() async {
        if (mode == DatabaseMode.EXISTING) {
          bool found = await _storage.find();
          if (!found) {
            throw new DatabaseException.databaseNotFound(
                "Database (open existing only) ${path} not found");
          }
        } else {
          if (mode == DatabaseMode.EMPTY) {
            await _storage.delete();
          }
          await _storage.findOrCreate();
        }
      }

      // create _exportStat
      if (_storage.supported) {
        _exportStat = new DatabaseExportStat();
      }
      await _findOrCreate();
      if (_storage.supported) {
        // empty stores
        _mainStore = null;
        _stores = new Map();
        _checkMainStore();

        _exportStat = new DatabaseExportStat();

        //bool needCompact = false;
        bool corrupted = false;

        await _storage.readLines().forEach((String line) {
          if (!corrupted) {
            _exportStat.lineCount++;

            Map map;

            try {
              // everything is JSON
              map = JSON.decode(line);
            } on FormatException catch (_) {
              if (_openMode == DatabaseMode.NEVER_FAILS) {
                corrupted = true;
                return;
              } else {
                rethrow;
              }
            }

            if (_Meta.isMapMeta(map)) {
              // meta?
              meta = new _Meta.fromMap(map);
            } else if (Record.isMapRecord(map)) {
              // record?
              Record record = new Record._fromMap(this, map);
              if (_hasRecord(record)) {
                _exportStat.obsoleteLineCount++;
              }
              _loadRecord(record);
            }
          }
        });
        // if corrupted and not even meta
        // delete it
        if (corrupted && meta == null) {
          await _storage.delete();
          await _storage.findOrCreate();
        } else {
          // auto compaction
          // allow for 20% of lost lines
          // make sure _meta is known before compacting
          _meta = meta;
          if (_needCompact || corrupted) {
            await compact();
          }
        }

        return await _openDone();
      } else {
        // ensure main store exists
        // but do not erase previous data
        _checkMainStore();
        meta = _meta;
        return _openDone();
      }
    });

  }

  void close() {
    _opened = false;
    //_mainStore = null;
    //_meta = null;
    // return new Future.value();
  }

  Map toJson() {
    Map map = new Map();
    if (path != null) {
      map["path"] = path;
    }
    if (version != null) {
      map["version"] = version;
    }
    if (_stores != null) {
      List stores = [];
      for (Store store in _stores.values) {
        stores.add(store.toJson());
      }
      map["stores"] = stores;
    }
    if (_exportStat != null) {
      map["exportStat"] = _exportStat.toJson();
    }
    return map;
  }

  DatabaseExportStat _exportStat;
  bool get _needCompact {
    return (_exportStat.obsoleteLineCount > 5 &&
        (_exportStat.obsoleteLineCount / _exportStat.lineCount > 0.20));
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class DatabaseExportStat {
  /// number of line in the export
  int lineCount = 0;

  /// number of lines that are obsolete
  int obsoleteLineCount = 0; // line that might have
  /// Number of time it has been compacted since being opened
  int compactCount = 0;

  DatabaseExportStat();

  DatabaseExportStat.fromJson(Map map) {
    if (map["lineCount"] != null) {
      lineCount = map["lineCount"];
    }
    if (map["compactCount"] != null) {
      compactCount = map["compactCount"];
    }
    if (map["obsoleteLineCount"] != null) {
      obsoleteLineCount = map["obsoleteLineCount"];
    }
  }
  Map toJson() {
    Map map = new Map();
    if (lineCount != null) {
      map["lineCount"] = lineCount;
    }
    if (obsoleteLineCount != null) {
      map["obsoleteLineCount"] = obsoleteLineCount;
    }
    if (compactCount != null) {
      map["compactCount"] = compactCount;
    }
    return map;
  }
}
