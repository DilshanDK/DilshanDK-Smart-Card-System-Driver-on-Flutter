import 'package:cloud_firestore/cloud_firestore.dart';

class LiveTrack {
  final String liveTrackId;    // Firestore document ID
  final String routeId;        // Current route reference
  final String driverId;       // Current driver reference
  final GeoPoint location;     // Current GPS coordinates
  final String status;         // Tracking status
  final double speed;          // In km/h
  final DateTime lastUpdated;  // Last position update
  final double etaToPassenger; // Estimated arrival in minutes

  LiveTrack({
    required this.liveTrackId,
    required this.routeId,
    required this.driverId,
    required this.location,
    this.status = 'active',
    this.speed = 0.0,
    DateTime? lastUpdated,
    this.etaToPassenger = 0.0,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory LiveTrack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LiveTrack(
      liveTrackId: doc.id,
      routeId: data['routeId']?.toString() ?? '',
      driverId: data['driverId']?.toString() ?? '',
      location: data['location'] as GeoPoint? ?? const GeoPoint(0.0, 0.0),
      status: _validateStatus(data['status']?.toString()),
      speed: (data['speed'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      etaToPassenger: (data['etaToPassenger'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'routeId': routeId,
      'driverId': driverId,
      'location': location,
      'status': status,
      'speed': speed,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'etaToPassenger': etaToPassenger,
    };
  }

  // Helper methods
  bool get isActive => status == 'active';
  bool get isOffline => status == 'offline';
  bool get isMoving => speed > 5.0; // Threshold in km/h

  LiveTrack copyWith({
    GeoPoint? location,
    String? status,
    double? speed,
    double? etaToPassenger,
  }) {
    return LiveTrack(
      liveTrackId: liveTrackId,
      routeId: routeId,
      driverId: driverId,
      location: location ?? this.location,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      lastUpdated: DateTime.now(), // Always update timestamp
      etaToPassenger: etaToPassenger ?? this.etaToPassenger,
    );
  }

  // Validate and normalize status
  static String _validateStatus(String? status) {
    const validStatuses = ['active', 'offline', 'maintenance', 'completed'];
    final normalized = status?.toLowerCase() ?? 'offline';
    return validStatuses.contains(normalized) ? normalized : 'offline';
  }
}