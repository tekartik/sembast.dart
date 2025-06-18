import 'dart:async';
import 'dart:js_interop';

import 'package:sembast_web/sembast_web.dart';
import 'package:sembast_web_worker_exp/shared.dart';
import 'package:web/web.dart' as web;

import 'ui.dart';

Future<void> main() async {
  // sqliteFfiWebDebugWebWorker = true;
  initUi();

  await incrementVarInWorker();
}

var sharedWorkerUri = Uri.parse('sw.dart.js');
late web.Worker worker;
var _webContextRegisterAndReady = () async {
  worker = web.Worker(sharedWorkerUri.toString().toJS);
}();

/// Returns response
Future<Object?> sendRawMessage(Object message) {
  var completer = Completer<Object?>();
  // This wraps the message posting/response in a promise, which will resolve if the response doesn't
  // contain an error, and reject with the error if it does. If you'd prefer, it's possible to call
  // controller.postMessage() and set up the onmessage handler independently of a promise, but this is
  // a convenient wrapper.
  var messageChannel = web.MessageChannel();
  //var receivePort =ReceivePort();

  final zone = Zone.current;
  messageChannel.port1.onmessage = (web.MessageEvent event) {
    zone.run(() {
      var data = event.data.dartify();

      completer.complete(data);
    });
  }.toJS;

  // This sends the message data as well as transferring messageChannel.port2 to the worker.
  // The worker can then use the transferred port to reply via postMessage(), which
  // will in turn trigger the onmessage handler on messageChannel.port1.
  // See https://html.spec.whatwg.org/multipage/workers.html#dom-worker-postmessage
  print('posting $message response ${messageChannel.port2}');
  worker.postMessage(
    message.jsify(),
    messagePortToPortMessageOption(messageChannel.port2),
  );
  return completer.future;
}

/// message port parameter
JSObject messagePortToPortMessageOption(web.MessagePort messagePort) {
  return [messagePort].toJS;
}

Future<int?> getTestValue() async {
  var response =
      await sendRawMessage([
            commandVarGet,
            {'key': storeKey},
          ])
          as Map;
  return (response['result'] as Map)['value'] as int?;
}

Future<void> setTestValue(int? value) async {
  await sendRawMessage([
    commandVarSet,
    {'key': storeKey, 'value': value},
  ]);
}

Future<void> incrementVarInWorker() async {
  await _webContextRegisterAndReady;
  write('shared worker ready');
  var value = await getTestValue();
  write('var before $value');
  if (value is! int) {
    value = 0;
  }

  await setTestValue(value + 1);
  value = await getTestValue();
  write('var after $value');
}

var databaseFuture = databaseFactoryWeb.openDatabase(databasePath);
Future<void> incrementVarInMain() async {
  var db = await databaseFuture;
  var value = await db.getTestValue();
  write('var before $value');
  if (value is! int) {
    value = 0;
  }

  await db.setTestValue(value + 1);
  value = await db.getTestValue();
  write('var after $value');
}

void initUi() {
  addButton('increment var in worker', () async {
    await incrementVarInWorker();
  });
  addButton('increment var in main', () async {
    await incrementVarInMain();
  });
  addButton('clear var in main', () async {
    var db = await databaseFuture;
    await db.setTestValue(null);
    var value = await db.getTestValue();
    write('var after $value');
  });
}
