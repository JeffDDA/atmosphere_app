import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current GOES animation frame index.
final goesFrameIndexProvider = StateProvider<int>((ref) => 0);

/// GOES satellite configuration and URL construction for RAMMB/CIRA SLIDER.
class GoesConfig {
  GoesConfig._();

  /// Select satellite based on observatory longitude.
  /// GOES-19 (East) for lon > -105°, GOES-18 (West) for lon <= -105°.
  static String satelliteForLongitude(double lon) {
    return lon > -105.0 ? 'goes-19' : 'goes-18';
  }

  /// Human-readable satellite label.
  static String satelliteLabel(String satellite) {
    return satellite == 'goes-19' ? 'GOES-19 East' : 'GOES-18 West';
  }

  /// Build the discovery URL for latest available timestamps.
  static String buildLatestTimesUrl(String satellite) {
    return 'https://slider.cira.colostate.edu/data/json/'
        '$satellite/conus/eumetsat_nighttime_microphysics/latest_times.json';
  }

  /// Build the tile URL for a specific timestamp.
  /// Timestamp is a 14-digit int: YYYYMMDDHHmmss.
  static String buildTileUrl(String satellite, int timestamp) {
    final ts = timestamp.toString();
    // Extract date components: YYYY/MM/DD
    final yyyy = ts.substring(0, 4);
    final mm = ts.substring(4, 6);
    final dd = ts.substring(6, 8);

    return 'https://slider.cira.colostate.edu/data/imagery/'
        '$yyyy/$mm/$dd/$satellite---conus/'
        'eumetsat_nighttime_microphysics/$ts/00/000_000.png';
  }

  /// Format a 14-digit timestamp to human-readable local time string.
  /// e.g. "11:30 PM"
  static String formatTimestamp(int timestamp) {
    final ts = timestamp.toString();
    final year = int.parse(ts.substring(0, 4));
    final month = int.parse(ts.substring(4, 6));
    final day = int.parse(ts.substring(6, 8));
    final hour = int.parse(ts.substring(8, 10));
    final minute = int.parse(ts.substring(10, 12));

    final utc = DateTime.utc(year, month, day, hour, minute);
    final local = utc.toLocal();

    final h = local.hour;
    final amPm = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : h > 12 ? h - 12 : h;
    final minuteStr = local.minute.toString().padLeft(2, '0');

    return '$displayHour:$minuteStr $amPm';
  }
}
