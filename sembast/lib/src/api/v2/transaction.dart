import 'package:sembast/src/api/client.dart';

/// Database transaction.
///
/// Actions executed in a transaction are atomic
abstract class Transaction implements DatabaseClient {}
