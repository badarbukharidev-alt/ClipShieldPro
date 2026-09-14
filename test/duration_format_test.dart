import 'package:flutter_test/flutter_test.dart';

import 'package:clipshield/utils/duration_format.dart';

/// A two-hour source used to be labelled "7200s". These pin that a length now
/// reads the way someone would say it, at every scale the app handles — a
/// 20-second short and a two-hour film share this one formatter.
void main() {
  group('under a minute stays in seconds', () {
    test('a short clip', () => expect(formatDuration(45), '45s'));
    test('one second', () => expect(formatDuration(1), '1s'));
    test('rounds to the nearest second', () => expect(formatDuration(45.6), '46s'));
    test('59 seconds is still seconds', () => expect(formatDuration(59), '59s'));
  });

  group('a minute or more reads in minutes', () {
    test('exactly a minute drops the seconds', () => expect(formatDuration(60), '1m'));
    test('a minute and a half', () => expect(formatDuration(90), '1m 30s'));
    test('a typical short video', () => expect(formatDuration(750), '12m 30s'));
    test('a round number of minutes has no trailing 0s',
        () => expect(formatDuration(600), '10m'));
    test('just under an hour', () => expect(formatDuration(3599), '59m 59s'));
  });

  group('an hour or more reads in hours', () {
    test('exactly an hour', () => expect(formatDuration(3600), '1h'));
    test('the long videos this app is for', () {
      expect(formatDuration(5040), '1h 24m');
      expect(formatDuration(7200), '2h');
      expect(formatDuration(9000), '2h 30m');
    });

    test('seconds are dropped next to an hour', () {
      // "1h 24m 07s" is harder to read at a glance, and the extra precision
      // means nothing at that scale.
      expect(formatDuration(5047), '1h 24m');
    });
  });

  group('nothing renders as a crash or a lie', () {
    test('zero and negatives', () {
      expect(formatDuration(0), '0s');
      expect(formatDuration(-5), '0s');
    });

    test('NaN and infinity, which a failed probe can produce', () {
      expect(formatDuration(double.nan), '0s');
      expect(formatDuration(double.infinity), '0s');
    });
  });

  test('a clip is measured from its own bounds', () {
    expect(formatClipDuration(30, 105), '1m 15s');
    expect(formatClipDuration(0, 42), '42s');
  });

  test('no output still carries a bare seconds count above a minute', () {
    for (final seconds in [61, 120, 3600, 7200, 12345]) {
      final shown = formatDuration(seconds.toDouble());
      expect(shown, isNot(matches(r'^\d+s$')),
          reason: '$seconds seconds must not be shown as a raw seconds count');
    }
  });
}
