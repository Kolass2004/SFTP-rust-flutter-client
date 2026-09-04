import 'package:intl/intl.dart';

class Formatters {
  /// Format byte counts to human readable strings (e.g. 1.2 MB, 45.6 KB).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes == 0) ? 0 : (bytes.toString().length - 1) ~/ 3;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    if (num >= 1000 && i < suffixes.length - 1) {
      num /= 1024;
      i++;
    }
    return '${num.toStringAsFixed(num >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  /// Format transfer speed (e.g. 3.4 MB/s).
  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 B/s';
    return '${formatBytes(bytesPerSec.toInt())}/s';
  }

  /// Format estimated time remaining in human readable format.
  static String formatEta(double seconds) {
    if (seconds.isInfinite || seconds.isNaN || seconds <= 0) return '--:--';
    final secs = seconds.toInt();
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;

    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  /// Format Unix epoch timestamp to localized date string.
  static String formatDate(int timestampSeconds) {
    if (timestampSeconds <= 0) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
    return DateFormat('MMM d, y • HH:mm').format(dt);
  }
}
