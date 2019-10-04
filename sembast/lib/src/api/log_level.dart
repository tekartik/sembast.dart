/// Sembast log level.
///
/// Not exposed
enum SembastLogLevel {
  /// No logs
  none,

  /// Log native verbose
  verbose
}

/// Default log level.
SembastLogLevel sembastLogLevel = SembastLogLevel.none;

/// Default log level.
SembastLogLevel databaseStorageLogLevel = SembastLogLevel.none;
