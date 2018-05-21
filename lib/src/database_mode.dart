///
/// The modes in which a Database can be opened.
///
class DatabaseMode {
  // use [databaseModeCreate] instead
  // deprecate since 2018-03-05 1.7.0
  @Deprecated("Use databaseModeCreate")
  static const CREATE = databaseModeCreate;

  // use [databaseModeEmpty] instead
  // deprecate since 2018-03-05 1.7.0
  @Deprecated("Use databaseModeExisting")
  static const EXISTING = databaseModeExisting;

  /// The mode for emptying the existing content if any
  // use [databaseModeCreate] instead
  // deprecate since 2018-03-05 1.7.0
  @Deprecated("Use databaseModeEmpty")
  static const EMPTY = databaseModeEmpty;

  // use [databaseModeNeverFails] instead
  // deprecate since 2018-03-05 1.7.0
  @Deprecated("Use databaseModeNeverFails")
  static const NEVER_FAILS = databaseModeNeverFails;

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

/// The database is created if not found
const databaseModeCreate = const DatabaseMode._internal(0);

/// Open an existing database, fail otherwise
const databaseModeExisting = const DatabaseMode._internal(1);

/// The mode for opening an existing database
const databaseModeEmpty = const DatabaseMode._internal(2);

/// This mode will never fails
/// Corrupted database will be deleted
/// This is the default
const databaseModeNeverFails = const DatabaseMode._internal(3);

/// Default open mode [databaseModeNeverFails]
const databaseModeDefault = databaseModeNeverFails;
