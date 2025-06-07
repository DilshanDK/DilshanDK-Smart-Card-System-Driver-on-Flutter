// ignore_for_file: use_build_context_synchronously, deprecated_member_use, sort_child_properties_last, unnecessary_brace_in_string_interps

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:smart_card_app_driver/services/bluetooth_service.dart';
import 'package:smart_card_app_driver/services/live_location_service.dart';
import 'package:smart_card_app_driver/themes/colors.dart';

class LiveLocationPage extends StatefulWidget {
  final String driverId;
  const LiveLocationPage({super.key, required this.driverId});

  @override
  State<LiveLocationPage> createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _busRoutes = [];
  bool _locationPermissionGranted = false;
  final _locationService = loc.Location();
  final String _orsApiKey = '5b3ce3597851110001cf62489fd877cac28a1d5e0cf6c210efe6f0ab7e2dedd65568cc1cbff91af5';
  GoogleMapController? _mapController;
  Timer? _blinkTimer;
  bool _showDriverMarker = true;
  BitmapDescriptor? _mainStopIcon;
  BitmapDescriptor? _driverIcon;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
    _requestLocationPermission();
    _startBlinking();
    _initializeMarkerIcons();
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _showDriverMarker = !_showDriverMarker;
      });
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoutes() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('routes').get();
      if (snapshot.docs.isEmpty) {
        _showSnackBar('No routes available.', color: AppColors.accentGreen);
        return;
      }
      setState(() {
        _busRoutes = snapshot.docs
            .map((doc) {
              final data = doc.data();
              final routeName = data['routeName'];
              if (routeName is String && routeName.isNotEmpty) {
                return {
                  'id': doc.id,
                  'name': routeName,
                  'routeId': data['routeId'] ?? doc.id,
                };
              }
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      });
    } catch (e, stack) {
      developer.log('Error fetching routes: $e', error: e, stackTrace: stack);
      _showSnackBar('Failed to load routes: $e', color: AppColors.errorRed);
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        setState(() {
          _locationPermissionGranted = true;
        });
        await _locationService.requestService();
        _locationService.changeSettings(
          accuracy: loc.LocationAccuracy.high,
          interval: 3000,
          distanceFilter: 0,
        );
        _locationService.onLocationChanged.listen((loc.LocationData currentLocation) {
          Provider.of<LiveLocationService>(context, listen: false)
              .updateCurrentLocation(currentLocation);
        });
        
        final liveLocationService = Provider.of<LiveLocationService>(context, listen: false);
        if (liveLocationService.selectedRouteId != null) {
          await _showRouteOnMap(liveLocationService.selectedRouteId!);
        }
      } else {
        setState(() {
          _locationPermissionGranted = false;
        });
        _showSnackBar(
          'Location permission denied. Map may not work properly.',
          color: AppColors.errorRed,
        );
      }
    } catch (e, stack) {
      developer.log('Error requesting location permission: $e', error: e, stackTrace: stack);
      _showSnackBar('Error requesting permission.', color: AppColors.errorRed);
    }
  }

  void _showSnackBar(String message, {Color color = AppColors.accentGreen}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: AppColors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<BitmapDescriptor> _createCustomMarkerIcon(IconData iconData, Color color, double size) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final iconStr = String.fromCharCode(iconData.codePoint);
    
    textPainter.text = TextSpan(
      text: iconStr,
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        color: color,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = bytes!.buffer.asUint8List();
    
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<void> _initializeMarkerIcons() async {
    _mainStopIcon = await _createCustomMarkerIcon(
      Icons.share_location_rounded,
      ui.Color.fromARGB(255, 180, 1, 48),
      100.0
    );
    _driverIcon = await _createCustomMarkerIcon(
      Icons.directions_bus,
      const ui.Color.fromARGB(255, 8, 11, 195),
      100.0,
    );
    setState(() {});
  }

  Future<void> _showRouteOnMap(String routeId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('routes').doc(routeId).get();
      if (!doc.exists) {
        _showSnackBar('Route not found.', color: AppColors.errorRed);
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final List<dynamic> mainStops = data['main_stops'] ?? [];
      if (mainStops.length < 2) {
        _showSnackBar('Route does not have enough main stops.', color: AppColors.errorRed);
        return;
      }

      final List<LatLng> mainStopLatLngs = [];
      final Set<Marker> markers = {};

      for (int i = 0; i < mainStops.length; i++) {
        final stop = mainStops[i];
        final location = stop['location'];
        if (location is GeoPoint) {
          final position = LatLng(location.latitude, location.longitude);
          mainStopLatLngs.add(position);

          markers.add(
            Marker(
              markerId: MarkerId('main_stop_${stop['mainId'] ?? i}'),
              position: position,
              infoWindow: InfoWindow(title: stop['name'] ?? 'Stop ${i + 1}'),
              icon: _mainStopIcon  ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          );
        }
      }

      final Set<Polyline> polylines = {};
      for (int i = 0; i < mainStopLatLngs.length - 1; i++) {
        final segment = await _fetchDrivingRoute([
          mainStopLatLngs[i],
          mainStopLatLngs[i + 1],
        ]);
        if (segment.length > 1) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('main_route_$i'),
              points: segment,
              color: Colors.blue,
              width: 5,
              visible: true,
            ),
          );
        }
      }
      final routeName = data['routeName'] ?? '';
      Provider.of<LiveLocationService>(context, listen: false).setSelectedRoute(
        routeId: routeId,
        routeName: routeName,
        markers: markers,
        polylines: polylines,
        mainStopLatLngs: mainStopLatLngs,
      );
      
      if (_mapController != null && mainStopLatLngs.isNotEmpty) {
        _animateToBounds(mainStopLatLngs);
      }
    } catch (e, stack) {
      developer.log('Error showing route on map: $e', error: e, stackTrace: stack);
      _showSnackBar('Failed to load route: $e', color: AppColors.errorRed);
    }
  }

  void _animateToBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;
    
    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;
    
    for (var point in points) {
      if (point.latitude < southWestLat) southWestLat = point.latitude;
      if (point.longitude < southWestLng) southWestLng = point.longitude;
      if (point.latitude > northEastLat) northEastLat = point.latitude;
      if (point.longitude > northEastLng) northEastLng = point.longitude;
    }
    
    final padding = 0.05;
    southWestLat -= padding;
    southWestLng -= padding;
    northEastLat += padding;
    northEastLng += padding;
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(southWestLat, southWestLng),
          northeast: LatLng(northEastLat, northEastLng),
        ),
        50.0,
      ),
    );
  }

  Future<List<LatLng>> _fetchDrivingRoute(List<LatLng> waypoints) async {
    try {
      final coordinates = waypoints.map((p) => [p.longitude, p.latitude]).toList();
      final url = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');
      final response = await http.post(
        url,
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'coordinates': coordinates, 'preference': 'recommended'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coords = data['features'][0]['geometry']['coordinates'];
        return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      } else {
        developer.log('Failed to fetch route: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e, stack) {
      developer.log('Error fetching driving route: $e', error: e, stackTrace: stack);
      return [];
    }
  }

  Set<Marker> _getAllMarkers() {
    final liveLocation = Provider.of<LiveLocationService>(context, listen: false);
    final Set<Marker> allMarkers = Set<Marker>.from(liveLocation.markers);
    
    if (liveLocation.driverPosition != null && _showDriverMarker) {
      allMarkers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: liveLocation.driverPosition!,
          icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          zIndex: 2,
        ),
      );
    }
    
    return allMarkers;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bluetoothService = Provider.of<BluetoothService>(context);
    final isBluetoothConnected = bluetoothService.connection != null;
    final liveLocation = Provider.of<LiveLocationService>(context);
    final isSharing = liveLocation.isSharing;
    final selectedRouteId = liveLocation.selectedRouteId;
    final selectedRouteName = liveLocation.selectedRouteName;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: _isFullscreen
          ? Stack(
              children: [
                _buildMapContent(liveLocation),
                
                // Route name header in fullscreen mode
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 35,
                      bottom: 35,
                      left: 16,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Route name
                        Row(
                          children: [
                            Icon(Icons.directions_bus, color: AppColors.white, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedRouteName ?? 'Route not selected',
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ), 
                      ],
                    ),
                  ),
                ),
                
                // Control buttons
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      if (liveLocation.isSharing && liveLocation.driverPosition != null)
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.primaryDark,
                          onPressed: () {
                            if (_mapController != null && liveLocation.driverPosition != null) {
                              _mapController!.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: liveLocation.driverPosition!,
                                    zoom: 15,
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Icon(Icons.my_location, size: 24),
                          tooltip: 'Focus on Driver',
                        ),
                      const SizedBox(height: 8),
                      if (selectedRouteId != null)
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.primaryDark,
                          onPressed: () {
                            if (_mapController != null && liveLocation.mainStopLatLngs.isNotEmpty) {
                              _animateToBounds(liveLocation.mainStopLatLngs);
                            }
                          },
                          child: const Icon(Icons.location_on, size: 24),
                          tooltip: 'Show All Stops',
                        ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primaryDark,
                        onPressed: () {
                          setState(() {
                            _isFullscreen = false;
                          });
                        },
                        child: const Icon(Icons.fullscreen_exit, size: 24),
                        tooltip: 'Exit Fullscreen',
                      ),
                    ],
                  ),
                ),
                
                // Back button at top left
                ],
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchRoutes();
                if (selectedRouteId != null) await _showRouteOnMap(selectedRouteId);
              },
              color: AppColors.accentGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBluetoothConnected)
                      Row(
                        children: [
                          Icon(Icons.bluetooth_connected, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            "NFC Reader Connected",
                            style: GoogleFonts.inter(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (isBluetoothConnected)
                      const SizedBox(height: 12),
                      
                    
                    const SizedBox(height: 8),
                    Text(
                      selectedRouteId != null
                          ? (liveLocation.selectedRouteName ?? 'Select a Route')
                          : 'Select a Route to Share',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      color: AppColors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.route, color: AppColors.primaryDark, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Bus Route',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AbsorbPointer(
                              absorbing: isSharing,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedRouteId,
                                hint: Text(
                                  'Choose a route',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: AppColors.grey600,
                                  ),
                                ),
                                items: _busRoutes.map((route) {
                                  return DropdownMenuItem<String>(
                                    value: route['id'],
                                    child: Text(
                                      route['name'],
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: AppColors.primaryDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) async {
                                  if (newValue != null) {
                                    await _showRouteOnMap(newValue);
                                  }
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.shadowGreen.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            if (isSharing)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock, color: AppColors.errorRed, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Route locked while sharing',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.errorRed,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (selectedRouteId != null)
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          height: 400,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _buildMapContent(liveLocation),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (selectedRouteId != null)
                      ElevatedButton.icon(
                        onPressed: isSharing
                            ? () => liveLocation.stopSharing()
                            : () => liveLocation.startSharing(widget.driverId, selectedRouteId),
                        icon: Icon(isSharing ? Icons.stop : Icons.location_on,color: AppColors.primaryDark, size: 20),
                        label: Text(
                          isSharing ? 'Stop Sharing Location' : 'Share Live Location',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSharing ? Colors.red : Colors.green,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 2,
                        ),
                      ),
                    if (isSharing)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Live location sharing is ACTIVE (${liveLocation.selectedRouteName})',
                          style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMapContent(LiveLocationService liveLocation) {
    return _locationPermissionGranted
        ? Stack(
            children: [
              GoogleMap(
                initialCameraPosition: liveLocation.mainStopLatLngs.isNotEmpty
                    ? CameraPosition(target: liveLocation.mainStopLatLngs[0], zoom: 12)
                    : const CameraPosition(target: LatLng(7.2906, 80.6337), zoom: 10),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                markers: _getAllMarkers(),
                polylines: liveLocation.polylines,
                mapToolbarEnabled: true,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                onCameraMove: (_) {},
              ),
              if (!_isFullscreen && (liveLocation.isSharing || liveLocation.driverPosition != null))
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primaryDark,
                        onPressed: () {
                          if (_mapController != null && liveLocation.driverPosition != null) {
                            _mapController!.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: liveLocation.driverPosition!,
                                  zoom: 15,
                                ),
                              ),
                            );
                          }
                        },
                        child: const Icon(Icons.my_location, size: 24),
                        tooltip: 'Focus on Driver',
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primaryDark,
                        onPressed: () {
                          if (_mapController != null && liveLocation.mainStopLatLngs.isNotEmpty) {
                            _animateToBounds(liveLocation.mainStopLatLngs);
                          }
                        },
                        child: const Icon(Icons.location_on, size: 24),
                        tooltip: 'Show All Stops',
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.primaryDark,
                        onPressed: () {
                          setState(() {
                            _isFullscreen = true;
                          });
                        },
                        child: const Icon(Icons.fullscreen, size: 24),
                        tooltip: 'Fullscreen Map',
                      ),
                    ],
                  ),
                ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 50,
                color: AppColors.errorRed,
              ),
              const SizedBox(height: 10),
              Text(
                'Location Permission Required',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _requestLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'Request Permission',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
  }
}