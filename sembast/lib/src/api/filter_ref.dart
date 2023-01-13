import 'package:sembast/src/import_common.dart';

/// A filter on a store. Not public.
abstract class FilterRef<K extends Key?, V extends Value?> {
  /// Find multiple records and listen for count changes.
  ///
  /// Returns a single subscriber stream that must be cancelled.
  Stream<int> onCount(Database database);
}
