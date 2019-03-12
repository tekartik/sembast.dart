import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';

/// @deprecated v2
abstract class Store extends StoreExecutor {
  ///
  /// Store reference
  ///
  StoreRef<dynamic, dynamic> get ref;

  ///
  /// Store name
  ///
  String get name;
}
