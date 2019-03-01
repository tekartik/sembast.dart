///
/// Exceptions
///
class DatabaseException implements Exception {
  /// Bad parameters
  static int errBadParam = 0;

  /// Database could not be found
  static int errDatabaseNotFound = 1;

  /// This is sent if the codec used does not match the one of the database
  static int errInvalidCodec = 2;

  final int _code;
  final String _message;

  int get code => _code;

  String get message => _message;

  DatabaseException.badParam(this._message) : _code = errBadParam;

  DatabaseException.databaseNotFound(this._message)
      : _code = errDatabaseNotFound;

  DatabaseException.invalidCodec(this._message) : _code = errInvalidCodec;

  @override
  String toString() => "[${_code}] ${_message}";
}
