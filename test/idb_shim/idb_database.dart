library tekartik_iodb.idb_database;

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_iodb/database.dart' as iodb;
import 'dart:async';
import 'package:path/path.dart';
import 'idb_common_meta.dart';

const IDB_IODB_DATABASE_MEMORY = "iodb";

class _IodbVersionChangeEvent extends VersionChangeEvent {

  final int oldVersion;
  final int newVersion;
  Request request;
  Object get target => request;
  Database get database => transaction.database;
  /**
     * added for convenience
     */
  _EmbsioTransaction get transaction => request.transaction;

  _IodbVersionChangeEvent(_IodbDatabase database, int oldVersion, this.newVersion) //
      : oldVersion = oldVersion == null ? 0 : oldVersion {

    // handle = too to catch programatical errors
    if (this.oldVersion >= newVersion) {
      throw new StateError("cannot downgrade from ${oldVersion} to $newVersion");
    }
    request = new OpenDBRequest(database, database.versionChangeTransaction);
  }
  @override
  String toString() {
    return "${oldVersion} => ${newVersion}";
  }
}

class _EmbsioTransaction extends Transaction {

  Completer completer;
  @override
  _IodbDatabase get database => super.database;

  final IdbTransactionMeta meta;
  _EmbsioTransaction(_IodbDatabase database, this.meta) : super(database);

  // TODO: implement completed
  @override
  Future<Database> get completed => completer == null ? new Future.value(database) : completer.future;

  @override
  ObjectStore objectStore(String name) {
    return new _IodbObjectStore(this, database.meta.getObjectStore(name));
  }
}
class _IodbObjectStore extends ObjectStore {

  final IdbObjectStoreMeta meta;
  final _EmbsioTransaction transaction;
  _IodbDatabase get database => transaction.database;
  iodb.Database get iodbDatabase => database.db;
  iodb.Store iodbStore;

  _IodbObjectStore(this.transaction, this.meta);

  @override
  Future add(value, [key]) {
    // TODO: implement add
    return null;
  }


  @override
  Future clear() {
    // TODO: implement clear
    return null;
  }

  @override
  Future<int> count([key_OR_range]) {
    // TODO: implement count
    return null;
  }

  @override
  Index createIndex(String name, keyPath, {bool unique, bool multiEntry}) {
    // TODO: implement createIndex
    return null;
  }

  @override
  Future delete(key) {
    // TODO: implement delete
    return null;
  }

  @override
  Future getObject(key) {
    // TODO: implement getObject
    return null;
  }

  @override
  Index index(String name) {
    // TODO: implement index
    return null;
  }

  // TODO: implement indexNames
  @override
  List<String> get indexNames => null;

  // TODO: implement name
  @override
  String get name => null;

  @override
  Stream<CursorWithValue> openCursor({key, KeyRange range, String direction, bool autoAdvance}) {
    // TODO: implement openCursor
    return null;
  }

  @override
  Future put(value, [key]) {
    // TODO: implement put
    return null;
  }

  // TODO: implement autoIncrement
  @override
  bool get autoIncrement => meta.autoIncrement;

  // TODO: implement keyPath
  @override
  get keyPath => meta.keyPath;
}

///
/// meta format
/// {"key":"version","value":1}
/// {"key":"stores","value":["test_store"]}
/// {"key":"store_test_store","value":{"name":"test_store","keyPath":"my_key","autoIncrement":true}}

class _IodbDatabase extends Database {

  _EmbsioTransaction versionChangeTransaction;
  final IdbDatabaseMeta meta = new IdbDatabaseMeta();
  final String _name;
  iodb.Database db;

  @override
  IdbDatabaseFactory get factory => super.factory;

  iodb.DatabaseFactory get iodbFactory => factory._databaseFactory;

  _IodbDatabase(IdbFactory factory, this._name) : super(factory);

  Future open(int newVersion, void onUpgradeNeeded(VersionChangeEvent event)) {
    int previousVersion;
    _open() {
      return iodbFactory.openDatabase(join(factory._path, _name), version: 1).then((iodb.Database db) {

        return db.inTransaction(() {

          return db.mainStore.get("version").then((int version) {
            previousVersion = version;
          }).then((_) {
            // read meta
            return db.mainStore.getRecord("stores").then((iodb.Record record) {
              if (record != null) {
                List<String> storeNames = record.value;
                List<String> keys = [];
                storeNames.forEach((String storeName) {
                  keys.add("store_${storeName}");
                });
                return db.mainStore.getRecords(keys).then((List<iodb.Record> records) {
                  records.forEach((iodb.Record record) {
                    Map map = record.value;
                    IdbObjectStoreMeta store = new IdbObjectStoreMeta(map["name"], map["keyPath"], map["autoIncrement"]);
                    meta.addObjectStore(store);


                  });
                });
              }

            });
          });
        }).then((_) => db);



      });
    }

    return _open().then((db) {
      if (newVersion != previousVersion) {
        List<IdbObjectStoreMeta> changedStores;

        meta.onUpgradeNeeded(() {
          versionChangeTransaction = new _EmbsioTransaction(this, meta.versionChangeTransaction);
          // could be null when opening an empty database
          if (onUpgradeNeeded != null) {
            onUpgradeNeeded(new _IodbVersionChangeEvent(this, previousVersion, newVersion));
          }
          changedStores = meta.versionChangeStores;
        });


        return db.inTransaction(() {

          return db.put(newVersion, "version").then((_) {
            if (changedStores.isNotEmpty) {
              return db.put(new List.from(objectStoreNames), "stores");
            }
          }).then((_) {
// write changes
            List<Future> futures = [];

            changedStores.forEach((IdbObjectStoreMeta storeMeta) {
              futures.add(db.put(storeMeta.toMap(), "store_${storeMeta.name}"));
            });

            return Future.wait(futures);

          });

        }).then((_) {
          // considered as opened
          meta.version = newVersion;
          this.db = db;
        });

      }
    });


  }

  @override
  void close() {
    // TODO: implement close
  }

  @override
  ObjectStore createObjectStore(String name, {String keyPath, bool autoIncrement}) {
    IdbObjectStoreMeta storeMeta = new IdbObjectStoreMeta(name, keyPath, autoIncrement);
    meta.createObjectStore(storeMeta);
    return new _IodbObjectStore(versionChangeTransaction, storeMeta);
  }

  @override
  void deleteObjectStore(String name) {
    throw 'not implemented';
  }

  // TODO: implement name
  @override
  String get name => _name;

  // TODO: implement objectStoreNames
  @override
  Iterable<String> get objectStoreNames {
    return meta.objectStoreNames;
  }

  // TODO: implement onVersionChange
  @override
  Stream<VersionChangeEvent> get onVersionChange => null;

  @override
  Transaction transaction(storeName_OR_storeNames, String mode) {
    IdbTransactionMeta txnMeta = meta.transaction(storeName_OR_storeNames, mode);
    return new _EmbsioTransaction(this, txnMeta);
  }

  @override
  Transaction transactionList(List<String> storeNames, String mode) {
    IdbTransactionMeta txnMeta = meta.transaction(storeNames, mode);
    return new _EmbsioTransaction(this, txnMeta);
  }

  // TODO: implement version
  @override
  int get version => db.version;

  Map toDebugMap() {
    Map map;
    if (meta != null) {
      map = meta.toDebugMap();
    } else {
      map = {};
    }

    if (db != null) {
      map["db"] = db.toDebugMap();
    }
    return map;
  }

  String toString() {
    return toDebugMap().toString();
  }
}
class IdbDatabaseFactory extends IdbFactory {

  final iodb.DatabaseFactory _databaseFactory;
  final String _path;

  @override
  bool get persistent => _databaseFactory.persistent;

  IdbDatabaseFactory(this._databaseFactory, this._path);

  String get name => IDB_IODB_DATABASE_MEMORY;


  @override
  Future<Database> open(String dbName, {int version, OnUpgradeNeededFunction onUpgradeNeeded, OnBlockedFunction onBlocked}) {

    // check params
    if ((version == null) != (onUpgradeNeeded == null)) {
      return new Future.error(new ArgumentError('version and onUpgradeNeeded must be specified together'));
    }
    if (version == 0) {
      return new Future.error(new ArgumentError('version cannot be 0'));
    } else if (version == null) {
      version = 1;
    }

    // name null no
    if (dbName == null) {
      return new Future.error(new ArgumentError('name cannot be null'));
    }

    _IodbDatabase db = new _IodbDatabase(this, dbName);

    return db.open(version, onUpgradeNeeded).then((_) {
      return db;
    });

  }

  Future<IdbFactory> deleteDatabase(String dbName, {void onBlocked(Event)}) {
    if (dbName == null) {
      return new Future.error(new ArgumentError('dbName cannot be null'));
    }
    return _databaseFactory.deleteDatabase(join(_path, dbName));
  }

  @override
  bool get supportsDatabaseNames {
    return false;
  }

  Future<List<String>> getDatabaseNames() {
    return null;
  }
}
