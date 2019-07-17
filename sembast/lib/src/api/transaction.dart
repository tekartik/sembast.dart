import 'package:sembast/src/api/compat/sembast.dart';
import 'package:sembast/src/api/v2/sembast.dart' as v2;

///
/// Database transaction
///
abstract class Transaction
    implements StoreTransaction, TransactionExecutor, v2.Transaction {}
