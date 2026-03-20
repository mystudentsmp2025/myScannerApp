import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Singleton pattern to maintain stream state
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _latestPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  Future<void> startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    await _positionStreamSubscription?.cancel();
    
    try {
      _latestPosition = await Geolocator.getLastKnownPosition();
    } catch (_) {}

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _latestPosition = position;
    });
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<Position?> getCurrentLocation({bool instant = false}) async {
    if (instant && _latestPosition != null) {
      return _latestPosition;
    }
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return null;
    } 

    if (instant) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _latestPosition = last;
          return last;
        }
      } catch (_) {}
    }

    // 2. Get current position
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5), // Don't block too long
      );
      _latestPosition = pos;
      return pos;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
}
