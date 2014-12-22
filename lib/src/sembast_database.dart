part of sembast;

class Database {

  static Logger logger = new Logger("Sembast");
  final bool LOGV = logger.isLoggable(Level.FINEST);

  final DatabaseStorage _storage;

  String get path => _storage.path;

  //int _rev = 0;
  // incremental for each transaction
  int _txnId = 0;
  Map<int, Transaction> _transactions = new Map();

  _Meta _meta;
  int get version => _meta.version;

  bool _opened = false;

  Store get mainStore => _mainStore;

  Store _mainStore;
  Map<String, Store> _stores = new Map();

  Iterable<Store> get stores => _stores.values;

  Database([this._storage]);

  Future onUpgrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

  Future onDowngrade(int oldVersion, int newVersion) {
    // default is to clear everything
    return new Future.value();
  }

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

  Completer _txnRootCompleter;
  Completer _txnChildCompleter;

  int get _currentZoneTxnId => Zone.current[_zoneTransactionKey];
  bool get _inTransaction => _currentZoneTxnId != null;
  ///
  /// get the current zone transaction
  ///
  Transaction get transaction {
    int txnId = _currentZoneTxnId;
    if (txnId == null) {
      return null;
    } else {
      return _transactions[_currentZoneTxnId];
    }
  }

  // for transaction
  static const _zoneTransactionKey = "sembast.txn"; // transaction key
  //static const _zoneChildKey = "sembast.txn.child"; // bool

  Future newTransaction(action()) {
    if (!_inTransaction) {
      return inTransaction(action);
    }
    Transaction txn = transaction;
    return txn.completed.then((_) {
      return newTransaction(action);
    });
  }
  Future inTransaction(action()) {

    //devPrint("z: ${Zone.current[_zoneRootKey]}");
    //devPrint("z: ${Zone.current[_zoneChildKey]}");

    // not in transaction yet
    if (!_inTransaction) {
      if ((_txnRootCompleter == null) || (_txnRootCompleter.isCompleted)) {
        _txnRootCompleter = new Completer();
      } else {
        return _txnRootCompleter.future.then((_) {
          return inTransaction(action);
        });
      }

      Completer actionCompleter = _txnRootCompleter;

      Transaction txn = new Transaction._(++_txnId);
      _transactions[txn.id] = txn;

      var result;
      var err;
      runZoned(() {
        // execute and commit
        if (LOGV) {
          logger.fine("begin transaction");
        }
        return new Future.sync(action).then((_result) {
          return new Future.sync(_commit).then((_) {
            result = _result;
            if (LOGV) {
              logger.fine("commit transaction");
            }
          });

        }).catchError((e, st) {
          logger.severe("txn error $e");
          logger.finest(e);
          logger.finest(st);
          //txn._completer.completeError(e);
          err = e;
          //return new Future.error(e);
          _transactions.remove(txn.id);
          _clearTxnData();
          txn._completer.complete();
          actionCompleter.completeError(err);
        });
      }, zoneValues: {
        _zoneTransactionKey: txn.id
      }, onError: (e, st) {
        logger.severe("txn zone error $e");
        logger.finest(e);
        logger.finest(st);
        //txn._completer.completeError(e);
        err = e;
        //return new Future.error(e);
        _transactions.remove(txn.id);
        _clearTxnData();
        txn._completer.complete();
        actionCompleter.completeError(err);

      }).whenComplete(() {
        if (!actionCompleter.isCompleted) {
          _transactions.remove(txn.id);
          _clearTxnData();
          actionCompleter.complete(result);
          txn._completer.complete();
        }


      });
      return actionCompleter.future;

    } else {
      return new Future.sync(action);
//      if (LOGV) {
//        logger.fine("inTxn ${transaction} start");
//      }
//      // in child transaction
//      // no commit yet
//      if ((_txnChildCompleter == null) || (_txnChildCompleter.isCompleted)) {
//        _txnChildCompleter = new Completer();
//      } else {
//        return _txnChildCompleter.future.then((_) {
//          return inTransaction(action);
//        });
//      }
//
//      Completer actionCompleter = _txnChildCompleter;
//
//      _done() {
//        if (LOGV) {
//          logger.fine("inTxn ${transaction} done");
//        }
//        actionCompleter.complete();
//      }
//      devPrint("inner ${transaction}");
//      return runZoned(() {
//        return new Future.sync(action);
//      }, zoneValues: {
//        _zoneChildKey: true
//      }, onError: (e, st) {
//        print("$e");
//        print("$st");
//        _done();
//        devPrint("inner ${transaction} error");
//      }).whenComplete(() {
//        _done();
//        devPrint("inner ${transaction} done");
//
//      });

    }


  }

  void _setRecordInMemory(Record record) {
    record.store._setRecordInMemory(record);
  }
  void _loadRecord(Record record) {
    record.store._loadRecord(record);
  }

  ///
  /// Compact the database (work in progress)
  ///
  Future compact() {
    return newTransaction(() {
      if (_storage.supported) {
        DatabaseStorage tmpStorage = _storage.tmpStorage;
        return tmpStorage.delete().then((_) {
          return tmpStorage.findOrCreate().then((_) {
            List<String> lines = [];
            lines.add(JSON.encode(_meta.toMap()));
            stores.forEach((Store store) {
              store._records.values.forEach((Record record) {
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
              });
            });
            return tmpStorage.appendLines(lines);

          });
        }).then((_) {
          return _storage.tmpRecover();
        });
      }
    });
  }
  // future or not
  _commit() {

    List<Record> txnRecords = [];
    for (Store store in stores) {
      if (store._txnRecords != null) {

        txnRecords.addAll(store._txnRecords.values);
      }
    }

    // end of commit
    _saveInMemory() {
      for (Record record in txnRecords) {
        _setRecordInMemory(record);
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
        return _storage.appendLines(lines).then((_) {
          _saveInMemory();
        });
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

  Future<Record> putRecord(Record record) {
    return inTransaction(() {
      return _putRecord(_cloneAndFix(record));
    });
  }

  ///
  /// Get a record by its key
  ///
  Future<Record> getRecord(var key) {
    return mainStore.getRecord(key);
  }

  Future<List<Record>> putRecords(List<Record> records) {
    return inTransaction(() {
      List<Record> toPut = [];
      for (Record record in records) {
        toPut.add(_cloneAndFix(record));
      }
      return _putRecords(toPut);
    });
  }

  ///
  /// find records in the main store
  ///
  Future<List<Record>> findRecords(Finder finder) {
    return mainStore.findRecords(finder);
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

  Future get(var key) {
    return _mainStore.get(key);
  }

  Future<int> count() {
    return _mainStore.count();
  }

  Future delete(var key) {
    return _mainStore.delete(key);
  }

  bool _hasRecord(Record record) {
    return record.store._has(record.key);
  }


  /**
   * reload from file system
   */
  Future reOpen({int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    close();
    return open(version: version, onVersionChanged: onVersionChanged, mode: mode);
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

  Future open({int version, OnVersionChangedFunction onVersionChanged, DatabaseMode mode}) {
    if (_opened) {
      if (path != this.path) {
        throw new DatabaseException.badParam("existing path ${this.path} differ from open path ${path}");
      }
      return new Future.value(this);
    }
    return runZoned(() {


      _Meta meta;

      Future _handleVersionChanged(int oldVersion, int newVersion) {
        var result;
        if (onVersionChanged != null) {
          result = onVersionChanged(this, oldVersion, newVersion);
        }

        return new Future.value(result).then((_) {
          meta = new _Meta(newVersion);

          if (_storage.supported) {
            return _storage.appendLine(JSON.encode(meta.toMap()));
          }
        });
      }

      Future _openDone() {
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
          return _handleVersionChanged(oldVersion, version).then((_) {
            _meta = meta;
            return this;
          });
        } else {
          _meta = meta;
          return new Future.value(this);
        }
      }

      //_path = path;
      Future _findOrCreate() {
        if (mode == DatabaseMode.EXISTING) {
          return _storage.find().then((bool found) {
            if (!found) {
              throw new DatabaseException.databaseNotFound("Database (open existing only) ${path} not found");
            }
          });
        } else {
          return _storage.findOrCreate();
        }
      }

      return _findOrCreate().then((_) {
        if (_storage.supported) {
          // empty stores
          _mainStore = null;
          _stores = new Map();
          _checkMainStore();

          int totalLines = 0;
          int obsoleteLines = 0;

          bool needCompact = false;


          return _storage.readLines().forEach((String line) {
            totalLines++;
            // evesrything is JSON
            Map map = JSON.decode(line);


            if (_Meta.isMapMeta(map)) {
              // meta?
              meta = new _Meta.fromMap(map);
            } else if (Record.isMapRecord(map)) {
              // record?
              Record record = new Record._fromMap(this, map);
              if (_hasRecord(record)) {
                obsoleteLines++;
              }
              _loadRecord(record);

            }


          }).then((_) {
            // auto compaction
            // allow for 20% of lost lines
            if (obsoleteLines > 5 && (obsoleteLines / totalLines > 0.20)) {
              return compact();
            }
          }).then((_) => _openDone());
        } else {
          // ensure main store exists
          // but do not erase previous data
          _checkMainStore();
          meta = _meta;
          return _openDone();
        }
      });
    }).catchError((e, st) {
      //devPrint("$e $st");
      throw e;
    });
  }



  void close() {
    _opened = false;
    //_mainStore = null;
    //_meta = null;
    // return new Future.value();
  }

  Map toDebugMap() {
    return {
      "path": path,
      "version": version,
      "stores": _stores
    };
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}
