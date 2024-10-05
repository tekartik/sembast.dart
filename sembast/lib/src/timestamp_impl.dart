/// A Timestamp represents a point in time independent of any time zone or
/// calendar, represented as seconds and fractions of seconds at nanosecond
/// resolution in UTC Epoch time.
///
/// Timestamps are encoded using the Proleptic Gregorian Calendar, which extends
/// the Gregorian calendar backwards to year one. Timestamps assume all minutes
/// are 60 seconds long, i.e. leap seconds are 'smeared' so that no leap second
/// table is needed for interpretation. Possible timestamp values range from
/// 0001-01-01T00:00:00Z to 9999-12-31T23:59:59.999999999Z.
class Timestamp implements Comparable<Timestamp> {
  /// [seconds] is the number of [seconds] of UTC time since Unix epoch
  /// 1970-01-01T00:00:00Z.
  final int seconds;

  /// [nanoseconds] is the non-negative fractions of a second at nanosecond
  /// resolution.
  final int nanoseconds;

  /// [seconds] is the number of [seconds] of UTC time since Unix epoch
  /// 1970-01-01T00:00:00Z.
  /// Must be from 0001-01-01T00:00:00Z to 9999-12-31T23:59:59Z inclusive.
  ///
  /// [nanoseconds] is the non-negative fractions of a second at nanosecond
  /// resolution. Negative second values with fractions must still have
  /// non-negative nanoseconds values that count forward in time.
  /// Must be from 0 to 999,999,999 inclusive.
  Timestamp(this.seconds, this.nanoseconds) {
    if (seconds < -62135596800 || seconds > 253402300799) {
      throw ArgumentError('invalid seconds part ${toDateTime(isUtc: true)}');
    }
    if (nanoseconds < 0 || nanoseconds > 999999999) {
      throw ArgumentError(
          'invalid nanoseconds part ${toDateTime(isUtc: true)}');
    }
  }

  static bool _isDigit(String chr) => (chr.codeUnitAt(0) ^ 0x30) <= 9;

  /// [parse] or returns null
  static Timestamp? tryParse(String? text) {
    if (text != null) {
      // 2018-10-20T05:13:45.985343Z

      // remove after the seconds part
      var subSecondsStart = text.lastIndexOf('.') + 1;
      // not found
      if (subSecondsStart == 0) {
        var dateTime = DateTime.tryParse(text);
        if (dateTime == null) {
          return null;
        } else {
          return Timestamp.fromDateTime(dateTime);
        }
      }
      var dateTimeNoSubSeconds = StringBuffer();
      dateTimeNoSubSeconds.write(text.substring(0, subSecondsStart));
      // Replace sub seconds with 000, which is safe on all platforms
      dateTimeNoSubSeconds.write('000');

      // Read the sun seconds part
      var nanosString = StringBuffer();
      var i = subSecondsStart;
      for (; i < text.length; i++) {
        var char = text[i];
        if (_isDigit(char)) {
          // Never write more than 9 chars
          if (nanosString.length < 9) {
            nanosString.write(char);
          }
        } else {
          // Write the end (timezone info)
          dateTimeNoSubSeconds.write(text.substring(i));
          break;
        }
      }

      // Use DateTime parser for everything but subseconds
      var dateTime = DateTime.tryParse(dateTimeNoSubSeconds.toString());
      if (dateTime == null) {
        return null;
      }

      // Never write less than 9 chars
      while (nanosString.length < 9) {
        nanosString.write('0');
      }

      var seconds = (dateTime.millisecondsSinceEpoch / 1000).floor();
      var nanoseconds = int.tryParse(nanosString.toString())!;
      return Timestamp(seconds, nanoseconds);
    }
    return null;
  }

  /// Creates a new [Timestamp] instance from the given date.
  ///
  /// Timestamp has no timezone/offset to UTC information so you don't need
  /// to convert dateTime to UTC.
  ///
  /// i.e.
  /// ```
  /// Timestamp.fromDateTime(dateTime);
  /// ```
  /// and
  /// ```
  /// Timestamp.fromDateTime(dateTime.toUtc());
  /// ```
  /// gives the same result.
  factory Timestamp.fromDateTime(DateTime dateTime) {
    final seconds = (dateTime.millisecondsSinceEpoch / 1000).floor();
    final nanoseconds = (dateTime.microsecondsSinceEpoch % 1000000) * 1000;
    return Timestamp(seconds, nanoseconds);
  }

  /// Constructs a new [Timestamp] instance
  /// with the given [millisecondsSinceEpoch].
  factory Timestamp.fromMillisecondsSinceEpoch(int millisecondsSinceEpoch) {
    final seconds = (millisecondsSinceEpoch / 1000).floor();
    final nanoseconds = (millisecondsSinceEpoch % 1000) * 1000000;
    return Timestamp(seconds, nanoseconds);
  }

  /// Constructs a new [Timestamp] instance
  /// with the given [microsecondsSinceEpoch].
  factory Timestamp.fromMicrosecondsSinceEpoch(int microsecondsSinceEpoch) {
    final seconds = (microsecondsSinceEpoch / 1000000).floor();
    final nanoseconds = (microsecondsSinceEpoch % 1000000) * 1000;
    return Timestamp(seconds, nanoseconds);
  }

  /// Constructs a [Timestamp] instance with current date and time.
  ///
  /// Timestamp has no timezone/offset to UTC information. This could
  /// have been written this way with the same result.
  /// `Timestamp.fromDateTime(DateTime.now().toUtc())`
  factory Timestamp.now() => Timestamp.fromDateTime(DateTime.now());

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Timestamp) {
      var typedOther = other;
      return seconds == typedOther.seconds &&
          nanoseconds == typedOther.nanoseconds;
    }
    return false;
  }

  @override
  int get hashCode => seconds * 17 + nanoseconds;

  /// The number of milliseconds since
  /// the 'Unix epoch' 1970-01-01T00:00:00Z (UTC).
  int get millisecondsSinceEpoch {
    return seconds * 1000 + (nanoseconds ~/ 1000000);
  }

  /// The number of microseconds since
  /// the 'Unix epoch' 1970-01-01T00:00:00Z (UTC).
  int get microsecondsSinceEpoch {
    return (seconds * 1000000 + (nanoseconds ~/ 1000));
  }

  /// Convert a Timestamp to a [DateTime] object. This conversion
  /// causes a loss of precision and support millisecond precision.
  DateTime toDateTime({bool? isUtc}) {
    return DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch,
        isUtc: isUtc == true);
  }

  static String _threeDigits(int n) {
    if (n >= 100) return '$n';
    if (n >= 10) return '0$n';
    return '00$n';
  }

  static String _formatNanos(int nanoseconds) {
    var ns = nanoseconds % 1000;
    if (ns != 0) {
      return '${_threeDigits(nanoseconds ~/ 1000000)}${_threeDigits((nanoseconds ~/ 1000) % 1000)}${_threeDigits(ns)}';
    } else {
      return _formatMicros(nanoseconds ~/ 1000);
    }
  }

  static String _formatMicros(int microseconds) {
    var us = microseconds % 1000;
    return '${_formatMillis(microseconds ~/ 1000)}${us == 0 ? '' : _threeDigits(us)}';
  }

  static String _formatMillis(int milliseconds) => _threeDigits(milliseconds);

  ///
  /// Returns an ISO-8601 full-precision extended format representation.
  /// The format is `yyyy-MM-ddTHH:mm:ss.mmmuuunnnZ`
  /// nanoseconds and microseconds are omitted if null
  String toIso8601String() {
    // Use DateTime without the sub second part
    var text = Timestamp(seconds, 0).toDateTime(isUtc: true).toIso8601String();
    // Then add the nano part to it
    var nanosStart = text.lastIndexOf('.') + 1;
    return '${text.substring(0, nanosStart)}${_formatNanos(nanoseconds)}Z';
  }

  @override
  String toString() => 'Timestamp(${toIso8601String()})';

  @override
  int compareTo(Timestamp other) {
    if (seconds != other.seconds) {
      return seconds - other.seconds;
    }
    return nanoseconds - other.nanoseconds;
  }

  /// The function parses a subset of ISO 8601
  /// which includes the subset accepted by RFC 3339.
  ///
  /// Compare to [DateTime.parse], it supports nanoseconds resolution
  static Timestamp parse(String text) {
    var timestamp = tryParse(text);
    if (timestamp == null) {
      throw FormatException('timestamp $text');
    }
    return timestamp;
  }

  /// Try to get a Timestamp from either a DateTime, a Timestamp, a text or
  /// an int (ms since epoch)
  static Timestamp? tryAnyAsTimestamp(dynamic any) {
    if (any is Timestamp) {
      return any;
    } else if (any is DateTime) {
      return Timestamp.fromDateTime(any);
    } else if (any is int) {
      return Timestamp.fromMillisecondsSinceEpoch(any);
    } else {
      return tryParse(any?.toString());
    }
  }
}

const _nanosPerSeconds = 1000000000;

/// Timestamp extension
extension TekartikSembastTimestampExt on Timestamp {
  Timestamp _addMicroseconds(int microseconds) {
    var nanoseconds = this.nanoseconds;
    var seconds = this.seconds;
    nanoseconds += microseconds * 1000;
    if (nanoseconds >= _nanosPerSeconds) {
      seconds += nanoseconds ~/ _nanosPerSeconds;
      nanoseconds %= _nanosPerSeconds;
    } else if (nanoseconds < 0) {
      seconds += (nanoseconds ~/ _nanosPerSeconds) + 1;
      nanoseconds %= _nanosPerSeconds;
    }
    return Timestamp(seconds, nanoseconds);
  }

  /// Add a duration to a timestamp
  Timestamp addDuration(Duration duration) {
    return _addMicroseconds(duration.inMicroseconds);
  }

  /// Substract a duration to a timestamp
  Timestamp substractDuration(Duration duration) {
    return _addMicroseconds(-duration.inMicroseconds);
  }
}
