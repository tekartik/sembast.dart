import 'dart:async';
import 'dart:js_interop';

import 'package:sembast_web/sembast_web.dart';
import 'package:sembast_web_worker_exp/shared.dart';
import 'package:web/web.dart' as web;

final scope = (globalContext as web.DedicatedWorkerGlobalScope);

var _database = databaseFactoryWebWorker.openDatabase(databasePath);

void _handleMessageEvent(web.Event event) async {
  var messageEvent = event as web.MessageEvent;
  var rawData = messageEvent.data.dartify();
  print('sw rawData $rawData');
  try {
    var jsPorts = messageEvent.ports;
    var ports = jsPorts.toDart;
    var port = ports.first;

    if (rawData is List) {
      var command = rawData[0];

      if (command == commandVarSet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var value = data['value'] as int?;
        var db = await _database;
        await db.setValue(key, value);

        port.postMessage(null);
      } else if (command == commandVarGet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var db = await _database;
        var value = await db.getValue(key);
        port.postMessage(
          {
            'result': {'key': key, 'value': value},
          }.jsify(),
        );
      } else {
        print('$command unknown');
        port.postMessage(null);
      }
    } else {
      print('rawData $rawData unknown');
      port.postMessage(null);
    }
  } catch (e) {
    print('error $e');
  }
}

void main(List<String> args) {
  var zone = Zone.current;

  print('Web worker started 1');

  /// Handle basic web workers
  /// dirty hack
  try {
    scope.onmessage = (web.MessageEvent event) {
      zone.run(() {
        _handleMessageEvent(event);
      });
    }.toJS;
  } catch (e) {
    print('onmessage error $e');
  }
}
