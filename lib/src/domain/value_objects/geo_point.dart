import 'dart:math' as math;
import 'package:jkdd_field_time_records_production/src/domain/enums/location_quality.dart';

final class GeoPoint {
  const GeoPoint(
      {required this.latitude,
      required this.longitude,
      required this.accuracyMeters,
      required this.capturedAt,
      this.isOfflineFallback = false});
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final bool isOfflineFallback;
  LocationQuality get quality {
    if (accuracyMeters <= 10) return LocationQuality.high;
    if (accuracyMeters <= 50) return LocationQuality.acceptable;
    if (accuracyMeters <= 100) return LocationQuality.low;
    return LocationQuality.unavailable;
  }

  double distanceToMeters(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLon = _rad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;
}
