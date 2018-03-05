///
/// The modes in which a Database can be opened.
///
class DatabaseMode {
  // use [databaseModeCreate] instead
  // deprecate since 2018-03-05 1.7.0
  @deprecated
  static const CREATE = const DatabaseMode._internal(0);

  // use [databaseModeEmpty] instead
  // deprecate since 2018-03-05 1.7.0
  @deprecated
  static const EXISTING = const DatabaseMode._internal(1);

  /// The mode for emptying the existing content if any
  // use [databaseModeCreate] instead
  // deprecate since 2018-03-05 1.7.0
  @deprecated
  static const EMPTY = const DatabaseMode._internal(2);

  // use [databaseModeNeverFails] instead
  // deprecate since 2018-03-05 1.7.0
  @deprecated
  static const NEVER_FAILS = const DatabaseMode._internal(3);

  final int _mode;

  const DatabaseMode._internal(this._mode);

  @override
  int get hashCode => _mode;

  @override
  bool operator ==(o) {
    if (o is DatabaseMode) {
      return o._mode == _mode;
    }
    return false;
  }
}
