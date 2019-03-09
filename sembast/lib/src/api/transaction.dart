import 'package:sembast/src/api/client.dart';
import 'package:sembast/src/api/compat/sembast.dart';

///
/// Database transaction
///
abstract class Transaction
    implements StoreTransaction, TransactionExecutor, DatabaseClient {}
