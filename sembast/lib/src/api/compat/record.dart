import 'package:sembast/sembast.dart';

/// @deprecated v2
///
/// Record
///
@deprecated
abstract class Record extends RecordSnapshot<dynamic, dynamic> {
  /// @deprecated v2
  ///
  /// true if the record has been deleted
  @deprecated
  bool get deleted;

  /// @deprecated v2
  ///
  /// set the [value] of the specified [field]
  ///
  @deprecated
  void operator []=(String field, dynamic value);
}
