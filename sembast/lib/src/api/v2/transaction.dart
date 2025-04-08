import 'dart:async';

import 'package:sembast/src/api/client.dart';

/// Database transaction.
///
/// Actions executed in a transaction are atomic
abstract class Transaction implements DatabaseClient {}

/// Transaction function.
typedef SembastTransactionFunction<T> =
    FutureOr<T> Function(Transaction transaction);
