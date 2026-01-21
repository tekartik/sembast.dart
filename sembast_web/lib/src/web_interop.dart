import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb_client_native.dart';

import 'package:sembast_web/src/jdb_import.dart';

import 'package:web/web.dart' as web;

/// The web jdb factory
final jdbFactoryIdbWeb = JdbFactoryWeb(idbFactoryWeb);

/// The web worker jdb factory
final jdbFactoryIdbWebWorker = JdbFactoryWeb(idbFactoryWebWorker);

/// The sembast database factory for the web.
final databaseFactoryWeb = DatabaseFactoryWeb(jdbFactoryIdbWeb);

/// The sembast database factory for web workers.
final databaseFactoryWebWorker = DatabaseFactoryWeb(jdbFactoryIdbWebWorker);

/// Web jdb factory.
class JdbFactoryWeb extends JdbFactoryIdb {
  /// Web jdb factory.
  JdbFactoryWeb(super.idbFactory);

  StreamSubscription? _revisionSubscription;

  @override
  void start() {
    stop();
    _revisionSubscription = notificationRevisionStream.listen((
      notificationRevision,
    ) {
      var list = databases[notificationRevision.name]!;
      for (var jdbDatabase in list) {
        jdbDatabase.addRevision(notificationRevision.revision);
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
  void notifyRevision(NotificationRevision notificationRevision) {
    addNotificationRevision(notificationRevision);
  }
}

/// Web factory.
class DatabaseFactoryWeb extends DatabaseFactoryJdb {
  /// Web factory.
  DatabaseFactoryWeb(super.jdbFactory);
}

/// add a storage revision
void addNotificationRevision(NotificationRevision notificationRevision) {
  if (debugNotificationRevision) {
    // ignore: avoid_print
    print('adding storage revision $notificationRevision');
  }
  _broadcastChannel.postMessage(
    JSArray.withLength(2)
      ..[0] = notificationRevision.name.toJS
      ..[1] = notificationRevision.revision.toJS,
  );
}

StreamController<NotificationRevision>? _notificationRevisionController;

/// Storage revision controller for web
final _broadcastChannel = web.BroadcastChannel('sembast_web_storage_revision');

/// Storage revision notification from all tabs
Stream<NotificationRevision> get notificationRevisionStream {
  _notificationRevisionController ??=
      StreamController<NotificationRevision>.broadcast(
        onListen: () {
          _broadcastChannel.onmessage = (web.MessageEvent event) {
            if (debugNotificationRevision) {
              // ignore: avoid_print
              print('getting ${event.data}');
            }
            var data = event.data;
            if (data.isA<JSArray>()) {
              var jsArray = data as JSArray;
              if (jsArray.length == 2) {
                var jsName = jsArray[0];
                var jsRevision = jsArray[1];
                if (jsName.isA<JSString>() && jsRevision.isA<JSNumber>()) {
                  var name = (jsName as JSString).toDart;
                  var revision = (jsRevision as JSNumber).toDartInt;
                  _notificationRevisionController?.add(
                    NotificationRevision(name, revision),
                  );
                }
              }
            }
          }.toJS;
        },
        onCancel: () {
          _broadcastChannel.onmessage = null;
        },
      );
  return _notificationRevisionController!.stream;
}
