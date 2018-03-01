part of sembast;

class Store {
  final Database database;

  ///
  /// Store name
  ///
  final String name;
  // for key generation
  int _lastIntKey = 0;

  Map<dynamic, Record> _records = new Map();
  Map<dynamic, Record> _txnRecords;

  bool get _inTransaction => database._inTransaction;

  Store._(this.database, this.name);

  ///
  /// return the key
  ///
  Future put(var value, [var key]) {
    return database.inTransaction(() {
      Record record = new Record._(this, key, value, false);

      _putRecord(record);
      if (database.LOGV) {
        Database.logger.fine("${database.transaction} put ${record}");
      }
      return record.key;
    });
  }

  ///
  /// stream all the records
  ///
  Stream<Record> get records {
    StreamController<Record> ctlr = new StreamController();
    inTransaction(() {
      _forEachRecords(null, (Record record) {
        ctlr.add(record);
      });
    }).then((_) {
      ctlr.close();
    });
    return ctlr.stream;
  }

  _forEachRecords(Filter filter, void action(Record record)) {
// handle record in transaction first
    if (_inTransaction && _txnRecords != null) {
      _txnRecords.values.forEach((Record record) {
        if (Filter.matchRecord(filter, record)) {
          action(record);
        }
      });
    }

    // then the regular unless already in transaction
    _records.values.forEach((Record record) {
      if (_inTransaction && _txnRecords != null) {
        if (_txnRecords.keys.contains(record.key)) {
          // already handled
          return;
        }
      }
      if (Filter.matchRecord(filter, record)) {
        action(record);
      }
    });
  }

  ///
  /// find the first matching record
  ///
  Future<Record> findRecord(Finder finder) {
    if (finder.limit != 1) {
      finder = finder.clone(limit: 1);
    }
    return findRecords(finder).then((List<Record> records) {
      if (records.isNotEmpty) {
        return records.first;
      }
      return null;
    });
  }

  ///
  /// find all records
  ///
  Future<List<Record>> findRecords(Finder finder) {
    return inTransaction(() {
      List<Record> result;

      result = [];

      _forEachRecords(finder.filter, (Record record) {
        result.add(record);
      });

      // sort
      result
          .sort((Record record1, record2) => finder.compare(record1, record2));
      return result;
    }) as Future<List<Record>>;
  }

  ///
  /// return true if it existed before
  ///
  bool _setRecordInMemory(Record record) {
    bool exists = (record.store._records[record.key] != null);
    if (record.deleted) {
      record.store._records.remove(record.key);
    } else {
      record.store._records[record.key] = record;
    }
    return exists;
  }

  void _loadRecord(Record record) {
    var key = record.key;
    _setRecordInMemory(record);
    // update for auto increment
    if (key is int) {
      if (key > _lastIntKey) {
        _lastIntKey = key;
      }
    }
  }

  ///
  /// execture the actions in a transaction
  /// use the current if any
  ///
  Future inTransaction(action()) {
    return database.inTransaction(action);
  }

  // Use Database.putRecord instead
  @deprecated
  Future<Record> putRecord(Record record) {
    return database.putRecord(record);
  }

  // Use Database.putRecords instead
  @deprecated
  Future<List<Record>> putRecords(List<Record> records) {
    return database.putRecords(records);
  }

  Record _putRecord(Record record) {
    assert(record.store == this);
    // auto-gen key if needed
    if (record.key == null) {
      record._key = ++_lastIntKey;
    } else {
      // update last int key in case auto gen is needed again
      if (record._key is int) {
        int intKey = record._key;
        if (intKey > _lastIntKey) {
          _lastIntKey = intKey;
        }
      }
    }

    // add to store transaction
    if (_txnRecords == null) {
      _txnRecords = new Map();
    }
    _txnRecords[record.key] = record;

    return record;
  }

  // record must have been clone before
  @deprecated
  List<Record> _putRecords(List<Record> records) {
    return database._putRecords(records);
  }

  Record _getRecord(var key) {
    var record;

    // look in current transaction
    if (_inTransaction) {
      if (_txnRecords != null) {
        record = _txnRecords[key];
      }
    }

    if (record == null) {
      record = _records[key];
    }
    if (database.LOGV) {
      Database.logger.fine("${database.transaction} get ${record} key ${key}");
    }
    return record as Record;
  }

  ///
  /// get a record by key
  ///
  Future<Record> getRecord(var key) {
    Record record = _getRecord(key);
    if (record != null) {
      if (record.deleted) {
        record = null;
      }
    }
    return new Future.value(record);
  }

  ///
  /// Get all records from a list of keys
  ///
  Future<List<Record>> getRecords(List keys) {
    List<Record> records = [];

    for (var key in keys) {
      Record record = _getRecord(key);
      if (record != null) {
        if (!record.deleted) {
          records.add(record);
          ;
        }
      }
    }
    return new Future.value(records);
  }

  ///
  /// get a value from a key
  ///
  Future get(var key) {
    return getRecord(key).then((Record record) {
      if (record != null) {
        return record.value;
      }
      return null;
    });
  }

  ///
  /// count all records
  ///
  Future<int> count([Filter filter]) {
    return inTransaction(() {
      int count = 0;
      _forEachRecords(filter, (Record record) {
        count++;
      });
      return count;
    }) as Future<int>;
  }

  ///
  /// delete a record by key
  ///
  Future delete(var key) {
    return inTransaction(() {
      Record record = _getRecord(key);
      if (record == null) {
        return null;
      } else {
        // clone to keep the existing as is
        Record clone = record._clone();
        clone._deleted = true;
        _putRecord(clone);
        return key;
      }
    });
  }

  ///
  /// return the list of deleted keys
  ///
  Future deleteAll(Iterable keys) {
    return inTransaction(() {
      List<Record> updates = [];
      List deletedKeys = [];
      for (var key in keys) {
        Record record = _getRecord(key);
        if (record != null) {
          Record clone = record._clone();
          clone._deleted = true;
          updates.add(clone);
          deletedKeys.add(key);
        }
      }

      if (updates.isNotEmpty) {
        database._putRecords(updates);
      }
      return deletedKeys;
    });
  }

  bool _has(var key) {
    return _records.containsKey(key);
  }

  void _rollback() {
    // clear map;
    _txnRecords = null;
  }

  ///
  /// debug json
  ///
  Map toJson() {
    Map map = {};
    if (name != null) {
      map["name"] = name;
    }
    if (_records != null) {
      map["count"] = _records.length;
    }
    return map;
  }

  @override
  String toString() {
    return "${name}";
  }

  ///
  /// delete all records in a store
  ///
  /// TODO: decide on return value
  ///
  Future clear() {
    return inTransaction(() {
      // first delete the one in transaction
      return new Future.sync(() {
        if (_txnRecords != null) {
          return deleteAll(new List.from(_txnRecords.keys, growable: false));
        }
      }).then((_) {
        Iterable keys = _records.keys;
        return deleteAll(new List.from(keys, growable: false));
      });
    });
  }
}
