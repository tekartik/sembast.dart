library tekartik_iodb.idb_meta;

class IdbTransactionMeta {

}

class IdbDatabaseMeta {
  IdbTransactionMeta _versionChangeTransaction;
  Map<String, IdbObjectStoreMeta> _stores = new Map();

  IdbTransactionMeta get versionChangeTransaction => _versionChangeTransaction;
  
  onUpgradeNeeded(action()) {
    _versionChangeTransaction = new IdbTransactionMeta();
    var result = action();
    _versionChangeTransaction = null;
    return result;
  }
  createObjectStore(IdbObjectStoreMeta store) {
    if (versionChangeTransaction == null) {
      throw new StateError("cannot create objectStore outside of a versionChangedEvent");
    }
    _stores[store.name] = store;
  }

  Iterable<String> get objectStoreNames => _stores.keys;


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

}
