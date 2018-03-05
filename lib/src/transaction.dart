import 'dart:async';
import 'package:sembast/sembast.dart';

class SembastTransaction extends Transaction {
  @deprecated
  int get id => _id;

  final int _id;

  // make the completer async as the Transaction following
  // action is not a priority
  Completer completer = new Completer();
  SembastTransaction(this._id);

  bool get isCompleted => completer.isCompleted;
  Future get completed => completer.future;

  @override
  String toString() {
    return "txn ${_id}${completer.isCompleted ? ' completed' : ''}";
  }
}