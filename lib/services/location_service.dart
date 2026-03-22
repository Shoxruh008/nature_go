import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static final LocationService _instance = LocationService._();
  static LocationService get instance => _instance;
  LocationService._();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  final Map<String, String> _addressCache = {};
  final Map<String, String> _cityCache = {};

  Future<bool> isServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<bool> isDeniedForever() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.deniedForever;
  }

  Future<bool> requestPermissionIfNeeded() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();

  Future<void> openSettings() =>
      Geolocator.openAppSettings();

  Future<Position?> getCurrentPosition() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );
      return _currentPosition;
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _currentPosition = last;
          return last;
        }
      } catch (_) {}
      return null;
    }
  }

  Future<String?> getCityName(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cityCache.containsKey(key)) return _cityCache[key];
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      String? result;
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        result = p.subLocality;
      } else if (p.locality != null && p.locality!.isNotEmpty) {
        result = p.locality;
      } else if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
        result = p.administrativeArea;
      }
      if (result != null) _cityCache[key] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getFullAddress(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_addressCache.containsKey(key)) return _addressCache[key];
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String>[];
      if (p.name != null &&
          p.name!.isNotEmpty &&
          p.name != p.locality) parts.add(p.name!);
      if (p.locality != null && p.locality!.isNotEmpty) {
        parts.add(p.locality!);
      }
      if (p.administrativeArea != null &&
          p.administrativeArea!.isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if (p.country != null && p.country!.isNotEmpty) {
        parts.add(p.country!);
      }
      final result = parts.isNotEmpty ? parts.join(', ') : null;
      if (result != null) _addressCache[key] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<LocationResult>> searchByAddress(String query) async {
    try {
      final locations = await locationFromAddress(query);
      final results = <LocationResult>[];
      for (final loc in locations.take(5)) {
        final name = await getCityName(loc.latitude, loc.longitude);
        results.add(LocationResult(
          lat: loc.latitude,
          lng: loc.longitude,
          label: name ?? query,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  static double distanceBetween(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }
}

class LocationResult {
  final double lat;
  final double lng;
  final String label;
  const LocationResult(
      {required this.lat, required this.lng, required this.label});
}