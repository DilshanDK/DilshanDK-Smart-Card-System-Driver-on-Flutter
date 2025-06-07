import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String driverId;      // Unique identifier
  final String name;         // Full name
  final String email;        // Email address
  final String phone;        // Contact number
  final DateTime createdAt;  // Registration date
  final String licenseNo;    // Driving license number
  final bool isActive;       // Active status flag

  Driver({
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    required this.licenseNo,
    this.isActive = true,    // Default to active
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Driver(
      driverId: data['driverId']?.toString() ?? doc.id, // Fallback to doc ID
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      licenseNo: data['licenseNo']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverId': driverId,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'licenseNo': licenseNo,
      'isActive': isActive,
    };
  }


  Driver copyWith({
    String? name,
    String? email,
    String? phone,
    String? licenseNo,
    bool? isActive,
  }) {
    return Driver(
      driverId: driverId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      licenseNo: licenseNo ?? this.licenseNo,
      isActive: isActive ?? this.isActive,
    );
  }
}