/// DMS ↔ decimal coordinate conversion utilities.
class CoordinateUtils {
  CoordinateUtils._();

  /// Format decimal degrees as DMS string.
  /// Example: `formatDMS(32.9, isLatitude: true)` → `32° 54' 00" N`
  static String formatDMS(double decimal, {required bool isLatitude}) {
    final abs = decimal.abs();
    final degrees = abs.truncate();
    final minutesFrac = (abs - degrees) * 60;
    final minutes = minutesFrac.truncate();
    final seconds = ((minutesFrac - minutes) * 60).round();

    final direction = isLatitude
        ? (decimal >= 0 ? 'N' : 'S')
        : (decimal >= 0 ? 'E' : 'W');

    return '$degrees\u00b0 ${minutes.toString().padLeft(2, '0')}\' '
        '${seconds.toString().padLeft(2, '0')}" $direction';
  }

  /// Parse a DMS string back to decimal degrees.
  /// Accepts: `32° 54' 00" N`, `32 54 00 N`, `32°54'00"N`
  /// Returns null if unparseable.
  static double? parseDMS(String dms) {
    final cleaned = dms.trim().toUpperCase();
    if (cleaned.isEmpty) return null;

    // Extract numbers and direction
    // Pattern: degrees ° minutes ' seconds " direction
    final regex = RegExp(
      r"(\d+)[\xb0\s]+(\d+)['`\s]+(\d+(?:\.\d+)?)"
      r'["\s]*([NSEW])?',
    );
    final match = regex.firstMatch(cleaned);
    if (match == null) return null;

    final degrees = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = double.parse(match.group(3)!);
    final direction = match.group(4);

    var result = degrees + minutes / 60.0 + seconds / 3600.0;

    if (direction == 'S' || direction == 'W') {
      result = -result;
    }

    return result;
  }

  /// Format decimal degrees with 4 decimal places.
  static String formatDecimal(double value) => value.toStringAsFixed(4);

  /// Default SQM value for a given Bortle class.
  static double sqmForBortle(int bortle) {
    const map = {
      1: 21.8,
      2: 21.5,
      3: 21.3,
      4: 21.0,
      5: 20.5,
      6: 20.0,
      7: 19.5,
      8: 19.0,
      9: 18.5,
    };
    return map[bortle.clamp(1, 9)] ?? 20.5;
  }
}
