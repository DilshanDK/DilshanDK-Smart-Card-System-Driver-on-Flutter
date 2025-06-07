import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a journey with start/end locations, timestamps, and associated metadata.
class Journey {
  final String journeyId; // Firestore document ID
  final String passengerId; // Reference to passenger document
  final GeoPoint startLocation; // Journey starting point
  final DateTime startTimestamp; // When journey began
  final GeoPoint? endLocation; // Journey end point (nullable)
  final DateTime? endTimestamp; // When journey ended (nullable)
  final String routeId; // Reference to route document
  final double totalCost; // Calculated journey cost
  final double distance; // Calculated distance of the journey

  Journey({
    required this.journeyId,
    required this.passengerId,
    required this.startLocation,
    required this.startTimestamp,
    this.endLocation,
    this.endTimestamp,
    required this.routeId,
    required this.totalCost,
    required this.distance,
  });

  /// Creates a [Journey] from a Firestore [DocumentSnapshot].
  /// Throws [FormatException] if required fields are missing or invalid.
  factory Journey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      throw FormatException('Document data is null for journeyId: ${doc.id}');
    }

    final passengerId = data['passengerId']?.toString();
    final routeId = data['routeId']?.toString();
    final startLocation = data['startLocation'] as GeoPoint?;
    final totalCost = data['totalCost'] as num?;
    final distance = data['distance'] as num?;

    // Validate required fields
    if (passengerId == null || passengerId.isEmpty) {
      throw FormatException('passengerId is missing or empty in document: ${doc.id}');
    }
    if (routeId == null || routeId.isEmpty) {
      throw FormatException('routeId is missing or empty in document: ${doc.id}');
    }
    if (startLocation == null) {
      throw FormatException('startLocation is missing in document: ${doc.id}');
    }
    if (totalCost == null) {
      throw FormatException('totalCost is missing in document: ${doc.id}');
    }
    if (distance == null) {
      throw FormatException('distance is missing in document: ${doc.id}');
    }

    return Journey(
      journeyId: doc.id,
      passengerId: passengerId,
      startLocation: startLocation,
      startTimestamp:
          (data['startTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endLocation: data['endLocation'] as GeoPoint?,
      endTimestamp: (data['endTimestamp'] as Timestamp?)?.toDate(),
      routeId: routeId,
      totalCost: totalCost.toDouble(),
      distance: distance.toDouble(),
    );
  }

  /// Converts the [Journey] to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'startLocation': startLocation,
      'startTimestamp': Timestamp.fromDate(startTimestamp),
      'endLocation': endLocation,
      'endTimestamp': endTimestamp != null ? Timestamp.fromDate(endTimestamp!) : null,
      'routeId': routeId,
      'totalCost': totalCost,
      'distance': distance,
    };
  }

  /// Indicates whether the journey is completed (has endLocation and endTimestamp).
  bool get isCompleted => endLocation != null && endTimestamp != null;

  /// Calculates the duration of the journey, if completed.
  Duration? get duration => endTimestamp?.difference(startTimestamp);

  /// Creates a copy of the [Journey] with updated fields.
  Journey copyWith({
    String? journeyId,
    String? passengerId,
    GeoPoint? startLocation,
    DateTime? startTimestamp,
    GeoPoint? endLocation,
    DateTime? endTimestamp,
    String? routeId,
    double? totalCost,
    double? distance,
  }) {
    return Journey(
      journeyId: journeyId ?? this.journeyId,
      passengerId: passengerId ?? this.passengerId,
      startLocation: startLocation ?? this.startLocation,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endLocation: endLocation ?? this.endLocation,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      routeId: routeId ?? this.routeId,
      totalCost: totalCost ?? this.totalCost,
      distance: distance ?? this.distance,
    );
  }
}