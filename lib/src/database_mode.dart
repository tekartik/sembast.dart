///
/// The modes in which a Database can be opened.
///
class DatabaseMode {
  /// The database is created if not found
  static const create = DatabaseMode._internal(0);

  /// Open an existing database, fail otherwise
  static const existing = DatabaseMode._internal(1);

  /// Empty the existing database
  static const empty = DatabaseMode._internal(2);

  /// This mode will never fails
  /// Corrupted database will be deleted
  /// This is the default
  static const neverFails = DatabaseMode._internal(3);

  /// Default open mode [neverFails]
  static const defaultMode = neverFails;

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
@deprecated
const databaseModeCreate = DatabaseMode.create;

@deprecated
const databaseModeExisting = DatabaseMode.existing;

@deprecated
const databaseModeEmpty = DatabaseMode.empty;

@deprecated
const databaseModeNeverFails = DatabaseMode.neverFails;

@deprecated
const databaseModeDefault = DatabaseMode.defaultMode;
