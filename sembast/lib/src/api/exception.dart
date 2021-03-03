///
/// Database exception.
///
class DatabaseException implements Exception {
  /// Bad parameters
  static int errBadParam = 0;

  /// Database could not be found
  static int errDatabaseNotFound = 1;

  /// This is sent if the codec used does not match the one of the database
  static int errInvalidCodec = 2;

  /// This is sent when an action happen after the database was closed.
  static int errDatabaseClosed = 3;

  final int _code;
  final String _message;

  /// Database exception code.
  int get code => _code;

  /// Database exception message.
  String get message => _message;

  /// Creates a bad param exception.
  DatabaseException.badParam(this._message) : _code = errBadParam;

  /// Creates a database not found exception.
  DatabaseException.databaseNotFound(this._message)
      : _code = errDatabaseNotFound;

  /// Creates an invalid codec exception.
  DatabaseException.invalidCodec(this._message) : _code = errInvalidCodec;

  /// Creates a database closed exception.
  DatabaseException.closed([this._message = 'database is closed'])
      : _code = errDatabaseClosed;

  @override
  String toString() => '[$_code] $_message';
}
