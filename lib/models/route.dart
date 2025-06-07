import 'package:cloud_firestore/cloud_firestore.dart';

class Route {
  final String routeId;
  final String routeName;
  final double costPerKm;
  final double distance;
  final DateTime createdAt;
  final List<MainStop> mainStops;
  final List<SubStop> subStops;

  Route({
    required this.routeId,
    required this.routeName,
    required this.costPerKm,
    required this.distance,
    required this.createdAt,
    required this.mainStops,
    required this.subStops,
  });

  factory Route.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Route(
      routeId: data['routeId'] ?? doc.id,
      routeName: data['routeName'] ?? '',
      costPerKm: (data['costPerKm'] ?? 0.0).toDouble(),
      distance: (data['distance'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mainStops: (data['main_stops'] as List<dynamic>?)
          ?.map((stop) => MainStop.fromMap(stop as Map<String, dynamic>))
          .toList() ?? [],
      subStops: (data['sub_stops'] as List<dynamic>?)
          ?.map((stop) => SubStop.fromMap(stop as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'costPerKm': costPerKm,
      'distance': distance,
      'createdAt': Timestamp.fromDate(createdAt),
      'main_stops': mainStops.map((stop) => stop.toMap()).toList(),
      'sub_stops': subStops.map((stop) => stop.toMap()).toList(),
    };
  }
}

class MainStop {
  final String mainId;
  final String name;
  final GeoPoint location;

  MainStop({
    required this.mainId,
    required this.name,
    required this.location,
  });

  factory MainStop.fromMap(Map<String, dynamic> map) {
    return MainStop(
      mainId: map['mainId'] ?? map['id'] ?? '',  // Backward compatible
      name: map['name'] ?? '',
      location: map['location'] as GeoPoint? ?? const GeoPoint(0.0, 0.0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mainId': mainId,
      'name': name,
      'location': location,
    };
  }
}

class SubStop {
  final String subId;
  final String name;
  final GeoPoint location;
  final String mainId;  // Changed from mainStopId to mainId for consistency
  final int order;

  SubStop({
    required this.subId,
    required this.name,
    required this.location,
    required this.mainId,
    required this.order,
  });

  factory SubStop.fromMap(Map<String, dynamic> map) {
    return SubStop(
      subId: map['subId'] ?? map['id'] ?? '',  // Backward compatible
      name: map['name'] ?? '',
      location: map['location'] as GeoPoint? ?? const GeoPoint(0.0, 0.0),
      mainId: map['mainId'] ?? map['mainStopId'] ?? '',  // Backward compatible
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subId': subId,
      'name': name,
      'location': location,
      'mainId': mainId,  // Consistent with field name
      'order': order,
    };
  }
}