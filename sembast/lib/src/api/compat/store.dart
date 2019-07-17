import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';

// ignore_for_file: deprecated_member_use_from_same_package

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
