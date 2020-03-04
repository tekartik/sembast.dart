import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';
import 'package:sembast/src/api/compat/sembast.dart';
// ignore_for_file: deprecated_member_use_from_same_package

/// @deprecated v2
@deprecated
abstract class Store extends StoreExecutor {
  ///
  /// Store reference
  ///
  @deprecated
  StoreRef<dynamic, dynamic> get ref;

  ///
  /// Store name
  ///
  @deprecated
  String get name;
}
