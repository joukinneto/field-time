import 'package:geolocator/geolocator.dart';
import 'package:jkdd_field_time_records_production/src/domain/value_objects/geo_point.dart';

final class TimeRecordLocationService {
  const TimeRecordLocationService();
  Future<GeoPoint> currentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return _fallbackLocation();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return _fallbackLocation();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp);
  }

  GeoPoint _fallbackLocation() => GeoPoint(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 9999,
        capturedAt: DateTime.now(),
        isOfflineFallback: true,
      );
}
