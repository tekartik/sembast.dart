import 'package:sembast/sembast.dart';
import 'package:sembast/src/boundary_impl.dart';

///
/// Sort order boundary, lower or upper to use in a [Finder]
///
abstract class Boundary {
  /// if true, the boundary will be included in the search result.
  ///
  /// defaults to false.
  bool get include;

  /// Create a boundary from a set of [values] or a given [record]
  ///
  /// if [include] is true, the record at the boundary will be included
  /// Number of values should match the number or sort orders
  ///
  /// [snapshot] superseeds record
  ///
  factory Boundary({
    RecordSnapshot? record,
    bool? include,
    List<Object?>? values,
  }) {
    return SembastBoundary(record: record, include: include, values: values);
  }
}
