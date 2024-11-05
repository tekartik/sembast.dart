import 'package:sembast/timestamp.dart';

import 'test_common.dart';

final dateTimeSupportsMicroseconds = () {
  var iso = DateTime.utc(2100, 1, 2, 3, 4, 5, 6, 7).toIso8601String();
  if (iso == '2100-01-02T03:04:05.006007Z') {
    return true;
  }
  return false;
}();
void main() {
  group('timestamp', () {
    test('dateTime parse', () {
      expect(DateTime.parse('1970-01-01T00:00:00.000000001Z').toIso8601String(),
          '1970-01-01T00:00:00.000Z');
      expect(DateTime.parse('1970-01-01T00:00:00.000000999Z').toIso8601String(),
          '1970-01-01T00:00:00.000Z');
      if (!dateTimeSupportsMicroseconds) {
        expect(DateTime.parse('1970-01-01T00:00:00.000001Z').toIso8601String(),
            '1970-01-01T00:00:00.000Z');
        expect(DateTime.parse('1970-01-01T00:00:00.000999Z').toIso8601String(),
            '1970-01-01T00:00:00.001Z'); // !!!
        expect(
            DateTime.parse('1970-01-01T00:00:00.000999999Z').toIso8601String(),
            '1970-01-01T00:00:00.001Z'); // !!!
        expect(
            DateTime.parse('1970-01-01T00:00:00.999999999Z').toIso8601String(),
            '1970-01-01T00:00:01.000Z'); // !!
      } else {
        expect(DateTime.parse('1970-01-01T00:00:00.000999Z').toIso8601String(),
            '1970-01-01T00:00:00.000999Z');
        expect(DateTime.parse('1970-01-01T00:00:00.000001Z').toIso8601String(),
            '1970-01-01T00:00:00.000001Z');
        expect(
            DateTime.parse('1970-01-01T00:00:00.000999999Z').toIso8601String(),
            '1970-01-01T00:00:00.000999Z');
        expect(
            DateTime.parse('1970-01-01T00:00:00.999999999Z').toIso8601String(),
            '1970-01-01T00:00:00.999999Z');
      }

      expect(DateTime.parse('1970-01-01T00:00:00.001Z').toIso8601String(),
          '1970-01-01T00:00:00.001Z');
      expect(DateTime.parse('1970-01-01T00:00:00.001Z').toIso8601String(),
          '1970-01-01T00:00:00.001Z');
    });
    test('epoch', () {
      var timestamp = Timestamp(0, 0);
      expect('Timestamp(${timestamp.toIso8601String()})', timestamp.toString());
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.000Z');
      expect(timestamp.millisecondsSinceEpoch, 0);
      expect(timestamp.microsecondsSinceEpoch, 0);

      timestamp = Timestamp(0, 1);
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.000000001Z');
      expect(timestamp.millisecondsSinceEpoch, 0);
      expect(timestamp.microsecondsSinceEpoch, 0);

      timestamp = Timestamp(0, 999);
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.000000999Z');
      expect(timestamp.millisecondsSinceEpoch, 0);
      expect(timestamp.microsecondsSinceEpoch, 0);

      timestamp = Timestamp(0, 1000);
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.000001Z');
      expect(timestamp.millisecondsSinceEpoch, 0);
      expect(timestamp.microsecondsSinceEpoch, 1);

      timestamp = Timestamp(0, 999999);
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.000999999Z');
      expect(timestamp.millisecondsSinceEpoch, 0);
      expect(timestamp.microsecondsSinceEpoch, 999);

      timestamp = Timestamp(0, 1000000);
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:00.001Z');
      expect(timestamp.millisecondsSinceEpoch, 1);
      expect(timestamp.microsecondsSinceEpoch, 1000);

      timestamp = Timestamp(1, 0);
      expect('Timestamp(${timestamp.toIso8601String()})', timestamp.toString());
      expect(timestamp.toIso8601String(), '1970-01-01T00:00:01.000Z');
      expect(timestamp.millisecondsSinceEpoch, 1000);
      expect(timestamp.microsecondsSinceEpoch, 1000000);

      timestamp = Timestamp.parse('1234-12-12T12:34:56.789Z');
      expect(
          Timestamp.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch),
          timestamp);
      timestamp = Timestamp.parse('1234-12-12T12:34:56.789123Z');
      expect(
          Timestamp.fromMicrosecondsSinceEpoch(timestamp.microsecondsSinceEpoch)
              .toIso8601String(),
          startsWith('1234-12-12T12:34:56.789')); // missing some precision !

      timestamp = Timestamp(1, 123000000);
      expect(
          Timestamp.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch),
          timestamp);
      timestamp = Timestamp(1, 123456000);
      expect(
          Timestamp.fromMicrosecondsSinceEpoch(
              timestamp.microsecondsSinceEpoch),
          timestamp);
    });
    test('equals', () {
      expect(Timestamp(1, 2), Timestamp(1, 2));
      expect(Timestamp(1, 2), isNot(Timestamp(1, 3)));
      expect(Timestamp(1, 2), isNot(Timestamp(0, 2)));
    });
    test('compareTo', () {
      expect(Timestamp(1, 2).compareTo(Timestamp(1, 2)), 0);
      expect(Timestamp(1, 2).compareTo(Timestamp(1, 3)), lessThan(0));
      expect(Timestamp(1, 2).compareTo(Timestamp(2, 2)), lessThan(0));
      expect(Timestamp(1, 2).compareTo(Timestamp(1, 1)), greaterThan(0));
      expect(Timestamp(1, 2).compareTo(Timestamp(0, 2)), greaterThan(0));
    });
    test('millisecondsSinceEpoch', () {
      var now = Timestamp(1, 1);
      expect(
          now.millisecondsSinceEpoch, now.toDateTime().millisecondsSinceEpoch);
      now = Timestamp.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch);
      expect(
          now.millisecondsSinceEpoch, now.toDateTime().millisecondsSinceEpoch);

      expect(
          now.microsecondsSinceEpoch, now.toDateTime().microsecondsSinceEpoch);
      now = Timestamp.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch);
      expect(
          now.millisecondsSinceEpoch, now.toDateTime().millisecondsSinceEpoch);
    });

    void checkToIso8601(
        Timestamp timestamp,
        String expectedTimestampToIso8601String,
        String expectedDateTimeToIso8601String) {
      var reason = '${timestamp.seconds} s ${timestamp.nanoseconds} ns';
      expect(timestamp.toIso8601String(), expectedTimestampToIso8601String,
          reason: 'timestamp $reason');
      expect(timestamp.toDateTime(isUtc: true).toIso8601String(),
          expectedDateTimeToIso8601String,
          reason: 'dateTime $reason');
      expect(Timestamp.parse(timestamp.toIso8601String()), timestamp,
          reason: 'timestamp $timestamp');
    }

    test('toIso8601', () {
      checkToIso8601(Timestamp(0, 0), '1970-01-01T00:00:00.000Z',
          '1970-01-01T00:00:00.000Z');
      checkToIso8601(Timestamp(0, 100000000), '1970-01-01T00:00:00.100Z',
          '1970-01-01T00:00:00.100Z');
      checkToIso8601(
        Timestamp(0, 100000),
        '1970-01-01T00:00:00.000100Z',
        dateTimeSupportsMicroseconds
            ? '1970-01-01T00:00:00.000100Z'
            : '1970-01-01T00:00:00.000Z',
      );
      checkToIso8601(
        Timestamp(0, 100),
        '1970-01-01T00:00:00.000000100Z',
        '1970-01-01T00:00:00.000Z',
      );
      checkToIso8601(
        Timestamp(0, 999999999),
        '1970-01-01T00:00:00.999999999Z',
        dateTimeSupportsMicroseconds
            ? '1970-01-01T00:00:00.999999Z'
            : '1970-01-01T00:00:01.000Z' // Precision issue
        ,
      );
    });

    test('limit', () {
      Timestamp(-62135596800, 0);
      Timestamp(253402300799, 999999999);

      expect(() => Timestamp(-62135596801, 0), throwsArgumentError);
      expect(() => Timestamp(253402300800, 0), throwsArgumentError);
      expect(() => Timestamp(0, -1), throwsArgumentError);
      expect(() => Timestamp(0, 1000000000), throwsArgumentError);
    });
    test('parse', () {
      void checkParseToIso(
        String text,
        String expectedTimestampToIso8601String,
        String expectedDateTimeToIso8601String,
      ) {
        var timestamp = Timestamp.parse(text);
        return checkToIso8601(timestamp, expectedTimestampToIso8601String,
            expectedDateTimeToIso8601String);
      }

      void checkParseSecondsNanos(
          String text, int expectedSeconds, int expectedNanos) {
        var timestamp = Timestamp.parse(text);
        expect(timestamp.seconds, expectedSeconds, reason: text);
        expect(timestamp.nanoseconds, expectedNanos, reason: text);
      }

      checkParseToIso(
          '2018-10-20T05:13:45.985343123Z',
          '2018-10-20T05:13:45.985343123Z',
          dateTimeSupportsMicroseconds
              ? '2018-10-20T05:13:45.985343Z'
              : '2018-10-20T05:13:45.985Z');
      checkParseToIso(
          '2018-10-20T05:13:45.98534312Z',
          '2018-10-20T05:13:45.985343120Z',
          dateTimeSupportsMicroseconds
              ? '2018-10-20T05:13:45.985343Z'
              : '2018-10-20T05:13:45.985Z');
      checkParseToIso(
          '2018-10-20T05:13:45.985343Z',
          '2018-10-20T05:13:45.985343Z',
          dateTimeSupportsMicroseconds
              ? '2018-10-20T05:13:45.985343Z'
              : '2018-10-20T05:13:45.985Z');
      checkParseToIso('2018-10-20T05:13:45.985Z', '2018-10-20T05:13:45.985Z',
          '2018-10-20T05:13:45.985Z');
      checkParseToIso('1234-01-23T01:23:45.123Z', '1234-01-23T01:23:45.123Z',
          '1234-01-23T01:23:45.123Z');

      checkParseToIso('2018-10-20T05:13:45Z', '2018-10-20T05:13:45.000Z',
          '2018-10-20T05:13:45.000Z');
      checkParseToIso('2018-10-20T05:13Z', '2018-10-20T05:13:00.000Z',
          '2018-10-20T05:13:00.000Z');
      checkParseToIso('2018-10-20T05Z', '2018-10-20T05:00:00.000Z',
          '2018-10-20T05:00:00.000Z');

      // 10 digits ignored!
      checkParseToIso(
          '2018-10-20T05:13:45.9853431239Z',
          '2018-10-20T05:13:45.985343123Z',
          dateTimeSupportsMicroseconds
              ? '2018-10-20T05:13:45.985343Z'
              : '2018-10-20T05:13:45.985Z');

      // Limit
      checkParseToIso('0001-01-01T00:00:00Z', '0001-01-01T00:00:00.000Z',
          '0001-01-01T00:00:00.000Z');
      if (!isWeb) {
        checkParseToIso('9999-12-31T23:59:59.999999999Z',
            '9999-12-31T23:59:59.999999999Z', '9999-12-31T23:59:59.999999Z');
      } else {
        // Before 2.7.1
        // isWeb ? '+010000-01-01T00:00:00.000Z' // Precision issue
        // After 2.7.1
        // Invalid argument(s): invalid seconds part 10000-01-01 00:00:01.000Z
      }
      // Parse local converted to utc
      expect(Timestamp.tryParse('2018-10-20T05:13:45.985')!.toIso8601String(),
          endsWith('.985Z'));
      expect(
          Timestamp.tryParse('2018-10-20T05:13:45.985123')!.toIso8601String(),
          endsWith('.985123Z'));
      expect(
          Timestamp.tryParse('2018-10-20T05:13:45.985123100')!
              .toIso8601String(),
          endsWith('.985123100Z'));

      // Limit
      checkParseSecondsNanos('0001-01-01T00:00:00Z', -62135596800, 0);
      if (!isWeb) {
        checkParseSecondsNanos(
            '9999-12-31T23:59:59.999999999Z', 253402300799, 999999999);
      } else {
        // After 2.7.1
        // Invalid argument(s): invalid seconds part 10000-01-01 00:00:01.000Z
      }
    });

    test('anyAsTimestamp', () {
      expect(Timestamp.tryAnyAsTimestamp(1000)!.toIso8601String(),
          '1970-01-01T00:00:01.000Z');
      expect(
          Timestamp.tryAnyAsTimestamp('1970-01-01T00:00:01.000Z')!
              .toIso8601String(),
          '1970-01-01T00:00:01.000Z');
      expect(
          Timestamp.tryAnyAsTimestamp('1970-01-01T00:00:01.000000Z')!
              .toIso8601String(),
          '1970-01-01T00:00:01.000Z');
      expect(Timestamp.tryAnyAsTimestamp(Timestamp(1, 0))!.toIso8601String(),
          '1970-01-01T00:00:01.000Z');
      expect(
          Timestamp.tryAnyAsTimestamp(
                  DateTime.fromMillisecondsSinceEpoch(1000))!
              .toIso8601String(),
          '1970-01-01T00:00:01.000Z');
      expect(Timestamp.tryAnyAsTimestamp('dummy'), null);
    });

    test('various', () {
      void checkTimestamp(Timestamp timestamp,
          {bool? testMillis, bool? testMicros}) {
        testMillis ??= false;
        testMicros ??= testMillis;
        var other = Timestamp.parse(timestamp.toIso8601String());
        expect(other, timestamp);
        other = Timestamp(timestamp.seconds, timestamp.nanoseconds);
        expect(other, timestamp);
        if (testMillis) {
          other = Timestamp.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch);
          expect(other, timestamp);
        }
        if (testMicros) {
          other = Timestamp.fromMicrosecondsSinceEpoch(
              timestamp.microsecondsSinceEpoch);
          expect(other, timestamp);
        }
      }

      checkTimestamp(Timestamp(0, 0), testMicros: true);
      checkTimestamp(Timestamp(0, 1), testMicros: false);
      checkTimestamp(Timestamp(0, 1000), testMicros: true);
      checkTimestamp(Timestamp(0, 999000), testMicros: true);
      checkTimestamp(Timestamp(0, 1000000), testMillis: true);
    });

    test('fromDateTime', () {
      var now = DateTime.now();
      expect(Timestamp.fromDateTime(now), Timestamp.fromDateTime(now.toUtc()));
    });

    test('toDateTime', () {
      var timestamp = Timestamp(1, 2);
      var dateTime = timestamp.toDateTime();
      var dateTimeUtc = timestamp.toDateTime(isUtc: true);
      expect(dateTime.isUtc, isFalse);
      expect(dateTimeUtc.isUtc, isTrue);
      expect(dateTimeUtc.toIso8601String(), '1970-01-01T00:00:01.000Z');
      expect(dateTime.toUtc(), dateTimeUtc);
    });
    test('addDuration', () {
      var timestamp = Timestamp(3, 300000);
      expect(timestamp.addDuration(const Duration(microseconds: 200)),
          Timestamp(3, 500000));
      expect(timestamp.substractDuration(const Duration(microseconds: 200)),
          Timestamp(3, 100000));
      expect(
          timestamp.addDuration(const Duration(seconds: 2, microseconds: 400)),
          Timestamp(5, 700000));
      expect(
          timestamp
              .substractDuration(const Duration(seconds: 2, microseconds: 400)),
          Timestamp(2, 999900000));
    });
    test('difference', () {
      expect(Timestamp(3, 1000).difference(Timestamp(3, 2000)),
          const Duration(microseconds: -1));
      expect(Timestamp(3, 2000).difference(Timestamp(3, 1000)),
          const Duration(microseconds: 1));
      expect(Timestamp(2, 1000).difference(Timestamp(3, 2000)),
          const Duration(microseconds: -1000001));
      expect(Timestamp(3, 1000).difference(Timestamp(2, 2000)),
          const Duration(microseconds: 999999));
      expect(Timestamp(62, 1000).difference(Timestamp(1, 2000)),
          const Duration(minutes: 1, microseconds: 999999));
    });
  });
}
