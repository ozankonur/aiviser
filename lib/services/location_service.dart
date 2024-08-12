import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  final _locationController = StreamController<LatLng>.broadcast();
  LatLng? _lastKnownLocation;
  final Duration _locationTimeout = const Duration(seconds: 20);
  final int _maxRetries = 3;
  bool _isDisposed = false;

  Stream<LatLng> get locationStream => _locationController.stream;

  Future<LatLng?> getLastKnownLocation() async {
    if (_lastKnownLocation != null) {
      return _lastKnownLocation;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? lat = prefs.getDouble('last_known_lat');
    double? lng = prefs.getDouble('last_known_lng');

    if (lat != null && lng != null) {
      _lastKnownLocation = LatLng(lat, lng);
      return _lastKnownLocation;
    }

    return null;
  }

  Future<LatLng> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    for (int i = 0; i < _maxRetries; i++) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: _locationTimeout,
        );
        LatLng location = LatLng(position.latitude, position.longitude);
        _updateLastKnownLocation(location);
        return location;
      } on TimeoutException {
        if (i == _maxRetries - 1) {
          // If this is the last retry, try to get the last known position
          Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
          if (lastKnownPosition != null) {
            LatLng location = LatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);
            _updateLastKnownLocation(location);
            return location;
          }
          // If even the last known position is null, fall back to the cached location
          LatLng? cachedLocation = await getLastKnownLocation();
          if (cachedLocation != null) {
            return cachedLocation;
          }
          return Future.error(
              'Unable to get location after multiple attempts. Please check your device settings and try again.');
        }
      } catch (e) {
        if (i == _maxRetries - 1) {
          return Future.error('Error getting location: $e');
        }
      }
      // Wait for a short duration before retrying
      await Future.delayed(const Duration(seconds: 2));
    }

    // This line should never be reached due to the error handling above, but Dart requires it
    throw Exception('Unexpected error in getCurrentLocation');
  }

  void startLocationUpdates() {
    if (_isDisposed) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (_isDisposed) return;
      LatLng location = LatLng(position.latitude, position.longitude);
      _locationController.add(location);
      _updateLastKnownLocation(location);
    });
  }

  void dispose() {
    _isDisposed = true;
    _locationController.close();
  }

  Future<void> _updateLastKnownLocation(LatLng location) async {
    _lastKnownLocation = location;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_known_lat', location.latitude);
    await prefs.setDouble('last_known_lng', location.longitude);
  }
}
