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
}
