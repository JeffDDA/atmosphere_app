import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cmc_projections.dart';

/// Current CMC forecast hour being displayed in the map view.
final cmcMapHourProvider = StateProvider<int>((ref) => 0);

/// CMC model run detection and URL construction.
///
/// CMC runs 4× daily at 00/06/12/18 UTC. Maps are typically available
/// ~6 hours after run start.
class CmcMapRun {
  CmcMapRun._();

  /// Estimate the latest available CMC model run.
  /// Returns the run date (YYYYMMDD) and hour (00/06/12/18).
  static ({String date, String hour}) estimateLatestMapRun() {
    final now = DateTime.now().toUtc();

    // Subtract 6h publication delay, then floor to nearest 6h cycle
    final adjusted = now.subtract(const Duration(hours: 6));
    final runHour = (adjusted.hour ~/ 6) * 6;

    final runDate = adjusted;
    final dateStr =
        '${runDate.year}${runDate.month.toString().padLeft(2, '0')}${runDate.day.toString().padLeft(2, '0')}';
    final hourStr = runHour.toString().padLeft(2, '0');

    return (date: dateStr, hour: hourStr);
  }

  /// Get the DateTime of the model run start.
  static DateTime runStartTime() {
    final run = estimateLatestMapRun();
    return DateTime.utc(
      int.parse(run.date.substring(0, 4)),
      int.parse(run.date.substring(4, 6)),
      int.parse(run.date.substring(6, 8)),
      int.parse(run.hour),
    );
  }

  /// Map a forecast hour DateTime to the CMC forecast hour offset.
  /// Returns the offset clamped to 0–84.
  static int forecastHourOffset(DateTime hourTime) {
    final runStart = runStartTime();
    final diff = hourTime.difference(runStart).inHours;
    return diff.clamp(0, 84);
  }

  /// Cloud quadrant region strings for the new URL format.
  static String _cloudRegion(String? quadrant) {
    switch (quadrant) {
      case 'NW':
        return 'north@america@northwest';
      case 'NE':
        return 'north@america@northeast';
      case 'SW':
        return 'north@america@southwest';
      case 'SE':
        return 'north@america@southeast';
      default:
        return 'north@america@northeast';
    }
  }

  /// Build the full URL for a CMC forecast map image.
  ///
  /// New format (2025+):
  /// Cloud: `{runId}_054_R1_north@america@northeast_I_ASTRO_nt_{fh}.png`
  /// Seeing: `{runId}_054_R1_north@america@astro_I_ASTRO_seeing_{fh}.png`
  /// Transparency: `{runId}_054_R1_north@america@astro_I_ASTRO_transp_{fh}.png`
  static String buildUrl({
    required CmcMapType type,
    String? quadrant,
    String? runDate,
    String? runHour,
    required int forecastHour,
  }) {
    final run = estimateLatestMapRun();
    final date = runDate ?? run.date;
    final hour = runHour ?? run.hour;
    final runId = '$date$hour';
    final fh = forecastHour.toString().padLeft(3, '0');

    String filename;
    switch (type) {
      case CmcMapType.cloud:
        final region = _cloudRegion(quadrant);
        filename = '${runId}_054_R1_${region}_I_ASTRO_nt_$fh.png';
      case CmcMapType.seeing:
        filename =
            '${runId}_054_R1_north@america@astro_I_ASTRO_seeing_$fh.png';
      case CmcMapType.transparency:
        filename =
            '${runId}_054_R1_north@america@astro_I_ASTRO_transp_$fh.png';
      case CmcMapType.wind:
        filename =
            '${runId}_054_R1_north@america@astro_I_ASTRO_uv_$fh.png';
      case CmcMapType.humidity:
        filename =
            '${runId}_054_R1_north@america@astro_I_ASTRO_hr_$fh.png';
      case CmcMapType.temperature:
        filename =
            '${runId}_054_R1_north@america@astro_I_ASTRO_tt_$fh.png';
    }

    return 'https://weather.gc.ca/data/prog/regional/$runId/$filename';
  }

  /// Human-readable label for the map type.
  static String mapTypeLabel(CmcMapType type) {
    switch (type) {
      case CmcMapType.cloud:
        return 'Cloud Cover';
      case CmcMapType.seeing:
        return 'Seeing';
      case CmcMapType.transparency:
        return 'Transparency';
      case CmcMapType.wind:
        return 'Wind';
      case CmcMapType.humidity:
        return 'Humidity';
      case CmcMapType.temperature:
        return 'Temperature';
    }
  }
}
