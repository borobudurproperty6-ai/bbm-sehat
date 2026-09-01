import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionOutcome { granted, denied, deniedForever, serviceDisabled }

/// Thin wrapper around geolocator — the rest of the app depends on this
/// instead of calling `Geolocator.*` directly, so the position source can
/// be swapped out (e.g. in a future test).
class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  Stream<Position> Function() _positionStreamFactory = () => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // A new point every ~5m walked is plenty dense for a route line
          // without flooding the live tracking state with near-duplicate
          // fixes while standing still.
          distanceFilter: 5,
        ),
      );

  @visibleForTesting
  static void debugOverridePositionStream(Stream<Position> Function() streamFactory) {
    instance._positionStreamFactory = streamFactory;
  }

  /// Checks (and, if needed, requests) location permission — call this
  /// before starting a walk session, since Android shows the system
  /// permission dialog the first time this is actually invoked, not just
  /// declared in the manifest.
  Future<LocationPermissionOutcome> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionOutcome.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationPermissionOutcome.granted,
      LocationPermission.deniedForever => LocationPermissionOutcome.deniedForever,
      LocationPermission.denied || LocationPermission.unableToDetermine => LocationPermissionOutcome.denied,
    };
  }

  Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Stream<Position> positionStream() => _positionStreamFactory();
}
