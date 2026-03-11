import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/forecast.dart';

// ── Response models ─────────────────────────────────────────────────────────

class ForecastLocation {
  final double latitude;
  final double longitude;
  final double elevationM;
  final int bortleClass;
  final String geohash;

  const ForecastLocation({
    required this.latitude,
    required this.longitude,
    required this.elevationM,
    required this.bortleClass,
    required this.geohash,
  });

  factory ForecastLocation.fromJson(Map<String, dynamic> json) {
    return ForecastLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevationM: (json['elevation_m'] as num?)?.toDouble() ?? 0,
      bortleClass: json['bortle_class'] as int? ?? 0,
      geohash: json['geohash'] as String? ?? '',
    );
  }
}

class ForecastResponse {
  final ForecastLocation location;
  final List<HourlyForecast> hours;
  final DateTime generatedAt;

  const ForecastResponse({
    required this.location,
    required this.hours,
    required this.generatedAt,
  });
}

class Observatory {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double? elevationM;
  final String? stateProvince;
  final String? country;
  final int? bortleClass;
  final double? distanceKm;

  const Observatory({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.elevationM,
    this.stateProvince,
    this.country,
    this.bortleClass,
    this.distanceKm,
  });

  factory Observatory.fromJson(Map<String, dynamic> json) {
    return Observatory(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevationM: (json['elevation_m'] as num?)?.toDouble(),
      stateProvince: json['state_province'] as String?,
      country: json['country'] as String?,
      bortleClass: json['bortle_class'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

class ObservatorySearchResponse {
  final List<Observatory> results;
  final int total;

  const ObservatorySearchResponse({
    required this.results,
    required this.total,
  });
}

// ── Errors ──────────────────────────────────────────────────────────────────

class DragonCDSError implements Exception {
  final String message;
  const DragonCDSError(this.message);
  @override
  String toString() => message;
}

class LocationNotFoundError extends DragonCDSError {
  const LocationNotFoundError()
      : super('Location not supported — DragonCDS covers North America only');
}

class NoForecastDataError extends DragonCDSError {
  const NoForecastDataError()
      : super('Forecast data is updating. Try again shortly.');
}

class ObservatoryNotFoundError extends DragonCDSError {
  const ObservatoryNotFoundError() : super('Observatory not found');
}

class DragonCDSNetworkError extends DragonCDSError {
  const DragonCDSNetworkError() : super('Unable to connect to forecast service');
}

// ── Service ─────────────────────────────────────────────────────────────────

class DragonCDSService {
  static const _baseUrl = 'https://cds.darkdragonsastro.com/api/v1';
  static const _timeout = Duration(seconds: 15);

  /// Fetch forecast for a lat/lon. Returns up to [hours] hourly forecasts.
  Future<ForecastResponse> getForecast({
    required double lat,
    required double lon,
    int hours = 84,
  }) async {
    final url = '$_baseUrl/forecast?lat=$lat&lon=$lon&hours=$hours';
    final body = await _get(url);

    final locationJson = body['location'] as Map<String, dynamic>;
    final forecastLocation = ForecastLocation.fromJson(locationJson);
    final bortle = forecastLocation.bortleClass;

    final forecastList = body['forecast'] as List<dynamic>;
    final forecastHours = forecastList
        .map((e) => HourlyForecast.fromApiJson(
              e as Map<String, dynamic>,
              bortleClass: bortle,
              latitude: forecastLocation.latitude,
              longitude: forecastLocation.longitude,
            ))
        .toList();

    final generatedAt = DateTime.tryParse(
          body['generated_at'] as String? ?? '',
        ) ??
        DateTime.now().toUtc();

    return ForecastResponse(
      location: forecastLocation,
      hours: forecastHours,
      generatedAt: generatedAt,
    );
  }

  /// Search observatories by text, spatial coordinates, or state filter.
  Future<ObservatorySearchResponse> searchObservatories({
    String? q,
    double? lat,
    double? lon,
    double? radiusKm,
    String? state,
    int limit = 20,
  }) async {
    final params = <String, String>{};
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (lat != null) params['lat'] = lat.toString();
    if (lon != null) params['lon'] = lon.toString();
    if (radiusKm != null) params['radius_km'] = radiusKm.toString();
    if (state != null && state.isNotEmpty) params['state'] = state;
    params['limit'] = limit.toString();

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = '$_baseUrl/observatories/search?$query';
    final body = await _get(url);

    final results = (body['results'] as List<dynamic>)
        .map((e) => Observatory.fromJson(e as Map<String, dynamic>))
        .toList();

    return ObservatorySearchResponse(
      results: results,
      total: body['total'] as int? ?? results.length,
    );
  }

  /// Fetch a single observatory by CDS ID.
  Future<Observatory> getObservatory(String id) async {
    final url = '$_baseUrl/observatories/$id';
    final body = await _get(url);
    return Observatory.fromJson(body);
  }

  Future<Map<String, dynamic>> _get(String url) async {
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // Parse error body
      Map<String, dynamic>? errorBody;
      try {
        errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final code = errorBody?['code'] as String? ?? '';

      switch (response.statusCode) {
        case 404:
          if (code == 'LOCATION_NOT_FOUND') throw const LocationNotFoundError();
          if (code == 'NOT_FOUND') throw const ObservatoryNotFoundError();
          throw DragonCDSError('Not found ($code)');
        case 503:
          if (code == 'NO_FORECAST_DATA') throw const NoForecastDataError();
          throw DragonCDSError('Service unavailable ($code)');
        default:
          throw DragonCDSError(
            'API error ${response.statusCode}: $code',
          );
      }
    } on DragonCDSError {
      rethrow;
    } catch (_) {
      throw const DragonCDSNetworkError();
    }
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

final dragonCDSServiceProvider = Provider<DragonCDSService>((_) {
  return DragonCDSService();
});
