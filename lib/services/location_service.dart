import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._();
  static LocationService get instance => _instance;
  LocationService._();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  final Map<String, String> _addressCache = {};
  final Map<String, String> _cityCache = {};

  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'NatureGoApp/1.0',
    'Accept-Language': 'uz,ru,en',
  };

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

  Future<void> openSettings() => Geolocator.openAppSettings();

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
      final data = await _reverseGeocode(lat, lng);
      if (data == null) return null;
      final addr = data['address'] as Map<String, dynamic>?;
      final result = addr?['city'] as String? ??
          addr?['town'] as String? ??
          addr?['village'] as String? ??
          addr?['county'] as String? ??
          addr?['state'] as String?;
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
      final data = await _reverseGeocode(lat, lng);
      if (data == null) return null;
      final display = data['display_name'] as String?;
      if (display != null && display.isNotEmpty) {
        final short = display.split(', ').take(4).join(', ');
        _addressCache[key] = short;
        return short;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<LocationResult>> searchByAddress(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_nominatimBase/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '6',
          'addressdetails': '1',
          'countrycodes': 'uz',
        },
      );
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        final lat = double.tryParse(m['lat'] as String? ?? '') ?? 0;
        final lng = double.tryParse(m['lon'] as String? ?? '') ?? 0;
        final label = (m['display_name'] as String? ?? '')
            .split(', ')
            .take(3)
            .join(', ');
        return LocationResult(lat: lat, lng: lng, label: label);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_nominatimBase/reverse').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
      },
    );
    final response = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>?;
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
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
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
  const LocationResult({required this.lat, required this.lng, required this.label});
}
