/// Formats a length in seconds the way a person would say it.
///
/// A two-hour source used to be labelled "7200s", which is technically correct
/// and useless. Minutes appear as soon as there is a minute to show, and hours
/// as soon as there is an hour.
///
/// Deliberately not `mm:ss`: "12:30" is read as half past twelve about as often
/// as twelve and a half minutes, and the same string has to serve a 20-second
/// short and a two-hour film.
String formatDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '0s';

  final int total = seconds.round();

  if (total < 60) return '${total}s';

  final int hours = total ~/ 3600;
  final int minutes = (total % 3600) ~/ 60;
  final int secs = total % 60;

  if (hours > 0) {
    // Seconds are noise next to an hour, and "1h 24m 07s" is harder to read at
    // a glance than "1h 24m".
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }

  return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
}

/// Same, for a clip whose bounds are known.
String formatClipDuration(double startTime, double endTime) =>
    formatDuration(endTime - startTime);
