@deprecated
library sembast.api.compat.v1.sembast;

export 'package:sembast/src/api/compat/finder.dart';
export 'package:sembast/src/api/compat/record.dart';
export 'package:sembast/src/api/compat/store.dart';
export 'package:sembast/src/api/database.dart';

// ignore_for_file: deprecated_member_use_from_same_package

/// @deprecated v2
@deprecated
abstract class TransactionExecutor extends DatabaseExecutor {}

/// @deprecated v2
@deprecated
abstract class DatabaseExecutor extends StoreExecutor {}

/// @deprecated v2
@deprecated
abstract class StoreExecutor extends BaseExecutor {}

/// @deprecated v2
///
/// Method shared by Store and Database (main store)
///
@deprecated
abstract class BaseExecutor {}

//import 'package:tekartik_core/dev_utils.dart';
/// @deprecated v2
@deprecated
abstract class StoreTransaction extends StoreExecutor {}
