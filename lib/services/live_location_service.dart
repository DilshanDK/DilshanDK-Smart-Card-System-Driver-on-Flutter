// ignore_for_file: avoid_print

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

/// LiveLocationService handles route selection, live sharing, blinking driver marker,
/// and can fetch the latest received key value from BluetoothService.
class LiveLocationService extends ChangeNotifier {
  // Sharing state and route info
  bool _isSharing = false;
  String? _driverId;
  String? _selectedRouteId;
  String? _selectedRouteName;

  // Timers for sharing and blinking
  Timer? _shareTimer;
  Timer? _blinkTimer;

  // Location
  final _locationService = loc.Location();
  loc.LocationData? _currentLocation;

  // Map overlays
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<LatLng> _mainStopLatLngs = [];

  // Blinking marker state
  bool _showDriverMarker = true;

  bool get isSharing => _isSharing;
  String? get selectedRouteId => _selectedRouteId;
  String? get selectedRouteName => _selectedRouteName;
  loc.LocationData? get currentLocation => _currentLocation;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers; // Now only returns stop markers, not driver location
  List<LatLng> get mainStopLatLngs => _mainStopLatLngs;
  bool get showDriverMarker => _showDriverMarker;

  // Add this getter to provide driver's position if available
  LatLng? get driverPosition {
    if (_currentLocation != null && 
        _currentLocation!.latitude != null && 
        _currentLocation!.longitude != null) {
      return LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!
      );
    }
    return null;
  }

  // Update current location from location service
  void updateCurrentLocation(loc.LocationData locationData) {
    _currentLocation = locationData;
    notifyListeners();
  }

  void setSelectedRoute({
    required String routeId,
    required String routeName,
    required Set<Marker> markers,
    required Set<Polyline> polylines,
    required List<LatLng> mainStopLatLngs,
  }) {
    _selectedRouteId = routeId;
    _selectedRouteName = routeName;
    _markers = markers;
    _polylines = polylines;
    _mainStopLatLngs = mainStopLatLngs;
    notifyListeners();
  }

  /// Start sharing live location for given driverId and routeId
  Future<void> startSharing(String driverId, String routeId) async {
    if (_isSharing) return;
    _driverId = driverId;
    _selectedRouteId = routeId;
    _isSharing = true;
    notifyListeners();

    final docId = '${_driverId}_$_selectedRouteId';
    await FirebaseFirestore.instance.collection('live_track').doc(docId).set({
      'status': 'active',
    }, SetOptions(merge: true));

    _shareTimer?.cancel();
    _shareTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _shareLocation();
    });

    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _showDriverMarker = !_showDriverMarker;
      notifyListeners();
    });
  }

  /// Stop live location sharing
  Future<void> stopSharing() async {
    if (!_isSharing) return;
    _shareTimer?.cancel();
    _blinkTimer?.cancel();
    _isSharing = false;
    _showDriverMarker = true;
    notifyListeners();

    if (_driverId != null && _selectedRouteId != null) {
      final docId = '${_driverId}_$_selectedRouteId';
      await FirebaseFirestore.instance.collection('live_track').doc(docId).update({
        'status': 'inactive',
      });
    }
  }

  /// Share current location to Firestore and update internal state
  Future<void> _shareLocation() async {
    if (_driverId == null || _selectedRouteId == null) return;
    try {
      final locData = await _locationService.getLocation();
      _currentLocation = locData;
      notifyListeners();
      final GeoPoint geo = GeoPoint(locData.latitude ?? 0.0, locData.longitude ?? 0.0);
      final double speed = (locData.speed ?? 0.0) * 3.6;
      final liveTrackData = {
        'routeId': _selectedRouteId!,
        'driverId': _driverId!,
        'location': geo,
        'status': 'active',
        'speed': speed,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
        'etaToPassenger': 0.0,
      };
      final docId = '${_driverId}_$_selectedRouteId';
      await FirebaseFirestore.instance
          .collection('live_track')
          .doc(docId)
          .set(liveTrackData, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _shareTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }
}