import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/store_ref.dart';

/// @deprecated v2
@deprecated
abstract class Store {
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
