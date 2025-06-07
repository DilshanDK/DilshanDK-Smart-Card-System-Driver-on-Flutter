import 'package:cloud_firestore/cloud_firestore.dart';

class Bus {
  final String busId;      // Firestore document ID (immutable)
  final String companyId;  // Reference to owning company (required)
  final String driverId;   // Current assigned driver (empty if unassigned)
  final String routeId;    // Current assigned route (empty if unassigned)

  Bus({
    required this.busId,
    required this.companyId,
    required this.driverId,
    required this.routeId,
  });

  factory Bus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Bus(
      busId: doc.id,
      companyId: data['companyId']?.toString() ?? '', // Ensures string conversion
      driverId: data['driverId']?.toString() ?? '',  // Empty if unassigned
      routeId: data['routeId']?.toString() ?? '',    // Empty if unassigned
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'driverId': driverId.isEmpty ? null : driverId, // Store null if empty
      'routeId': routeId.isEmpty ? null : routeId,    // Store null if empty
    };
  }

  // Helper method for immutable updates
  Bus copyWith({
    String? companyId,
    String? driverId,
    String? routeId,
  }) {
    return Bus(
      busId: busId, // Always keep original busId
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      routeId: routeId ?? this.routeId,
    );
  }

}