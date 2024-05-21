import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb_client_native.dart';
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:sembast_web/src/jdb_import.dart';
import 'package:sembast_web/src/web_defs.dart';
import 'package:web/web.dart' as web;

/// The native jdb factory
var jdbFactoryIdbNative = JdbFactoryWeb();

/// The sembast idb native factory with web.
var databaseFactoryWeb = DatabaseFactoryWeb();

/// Web jdb factory.
class JdbFactoryWeb extends JdbFactoryIdb {
  /// Web jdb factory.
  JdbFactoryWeb() : super(idbFactoryNative);

  StreamSubscription? _revisionSubscription;

  @override
  void start() {
    stop();
    _revisionSubscription = storageRevisionStream.listen((storageRevision) {
      var list = databases[storageRevision.name]!;
      for (var jdbDatabase in list) {
        jdbDatabase.addRevision(storageRevision.revision);
      }
    });
  }

  @override
  void stop() {
    _revisionSubscription?.cancel();
    _revisionSubscription = null;
  }

  /// Notify other app (web only))
  @override
  void notifyRevision(StorageRevision storageRevision) {
    addStorageRevision(storageRevision);
  }
}

/// Web factory.
class DatabaseFactoryWeb extends DatabaseFactoryJdb {
  /// Web factory.
  DatabaseFactoryWeb() : super(jdbFactoryIdbNative);
}

String _sembastStorageKeyPrefix = 'sembast_web/revision:';

/// add a storage revision
void addStorageRevision(StorageRevision storageRevision) {
  if (debugStorageNotification) {
    // ignore: avoid_print
    print('adding storage revision $storageRevision');
  }
  var key = '$_sembastStorageKeyPrefix${storageRevision.name}';
  if (storageRevision.revision != 0) {
    web.window.localStorage.setItem(key, storageRevision.revision.toString());
  } else {
    web.window.localStorage.removeItem(key);
  }
}

StreamController<StorageRevision>? _storageRevisionController;

/// Storage revision notification from all tabs
Stream<StorageRevision> get storageRevisionStream {
  _storageRevisionController ??=
      StreamController<StorageRevision>.broadcast(onListen: () {
    web.window.onstorage = (web.StorageEvent event) {
      if (debugStorageNotification) {
        // ignore: avoid_print
        print('getting ${event.key}: ${event.newValue}');
      }
      if (event.key?.startsWith(_sembastStorageKeyPrefix) ?? false) {
        var name = event.key!.substring(_sembastStorageKeyPrefix.length);
        var revision =
            event.newValue == null ? 0 : (int.tryParse(event.newValue!) ?? 0);
        _storageRevisionController?.add(StorageRevision(name, revision));
      }
    }.toJS;
  }, onCancel: () {
    web.window.onstorage = null;
    _storageRevisionController = null;
  });
  return _storageRevisionController!.stream;
}
