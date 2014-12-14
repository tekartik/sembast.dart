library tekartik_iodb.idb_meta;

import 'package:idb_shim/idb_client.dart';

class IdbTransactionMeta {
  String mode;
  List<String> storeNames;
  IdbTransactionMeta(this.storeNames, this.mode);
}

class IdbDatabaseMeta {
  int version;
  IdbTransactionMeta _versionChangeTransaction;
  List<IdbObjectStoreMeta> versionChangeStores; // store modified during onUpgradeNeeded
  Map<String, IdbObjectStoreMeta> _stores = new Map();

  IdbTransactionMeta get versionChangeTransaction => _versionChangeTransaction;

  onUpgradeNeeded(action()) {

    versionChangeStores = [];
    _versionChangeTransaction = new IdbTransactionMeta(null, IDB_MODE_READ_WRITE);
    var result = action();
    _versionChangeTransaction = null;
    versionChangeStores = null;
    return result;
  }
  createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw new StateError("cannot create objectStore outside of a versionChangedEvent");
    }
    versionChangeStores.add(store);
    addObjectStore(store);
  }

  bool _containsStore(String storeName) {
    return _stores.keys.contains(storeName);
  }

  IdbTransactionMeta transaction(storeName_OR_storeNames, String mode) {
    // Check store(s) exist
    if (storeName_OR_storeNames is String) {
      if (!_containsStore(storeName_OR_storeNames)) {
        throw new DatabaseStoreNotFoundError();
      }
      return new IdbTransactionMeta([storeName_OR_storeNames], mode);
    } else if (storeName_OR_storeNames is List) {
      for (String storeName in storeName_OR_storeNames) {
        if (!_containsStore(storeName)) {
          throw new DatabaseStoreNotFoundError();
        }
      }
      return new IdbTransactionMeta(storeName_OR_storeNames, mode);
    } else {
      // assume null - it will complain otherwise
      return new IdbTransactionMeta(storeName_OR_storeNames, mode);
    }
      
  }

  addObjectStore(IdbObjectStoreMeta store) {
    _stores[store.name] = store;
  }

  Iterable<String> get objectStoreNames => _stores.keys;

  Map<String, Object> toDebugMap() {
    Map map = {
      "stores": _stores,
      "version": version
    };
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }

  IdbObjectStoreMeta getObjectStore(String name) {
    return _stores[name];
  }
}

class IdbIndexMeta {
  final IdbObjectStoreMeta storeMeta;
  final String name;
  final String keyPath;
  final bool unique;
  final bool multiEntry;
  IdbIndexMeta(this.storeMeta, this.name, this.keyPath, bool unique, bool multiEntry)
      : multiEntry = (multiEntry == true),
        unique = (unique == true);


  @override
  String toString() {
    return "index $name on $keyPath unique ${unique} multi ${multiEntry}";
  }

}


// meta data is loaded only once
class IdbObjectStoreMeta {

  final String name;
  final String keyPath;
  final bool autoIncrement;

  Map<String, IdbIndexMeta> indecies = new Map();

  Iterable<String> get indexNames => indecies.keys;

  IdbObjectStoreMeta(this.name, this.keyPath, bool autoIncrement) : autoIncrement = (autoIncrement == true);

  IdbObjectStoreMeta.fromMap(Map<String, Object> map) //
      : this(map["name"], //
      map["keyPath"], //
      map["autoIncrement"]);

  Map toDebugMap() {
    return toMap();
  }
  Map<String, Object> toMap() {
    Map map = {
      "name": name
    };
    if (keyPath != null) {
      map["keyPath"] = keyPath;
    }
    if (autoIncrement) {
      map["autoIncrement"] = autoIncrement;
    }
    return map;
  }

  @override
  String toString() {
    return toDebugMap().toString();
  }
}
