import 'package:sembast/src/api/sembast.dart';

/// A filter on a store. Not public.
abstract class FilterRef<K, V> {
  /// Find multiple records and listen for count changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<int> onCount(Database database);
}
