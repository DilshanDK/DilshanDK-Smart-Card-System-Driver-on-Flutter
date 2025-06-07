// import 'package:cloud_firestore/cloud_firestore.dart';

// class Passenger {
//   final String passengerId;     // Unique identifier
//   final String name;           // Full name
//   final String email;          // Email (should be unique)
//   final String phone;          // Phone number
//   final double walletBalance;  // Current balance
//   final DateTime createdAt;    // Account creation date

//   Passenger({
//     required this.passengerId,
//     required this.name,
//     required this.email,
//     required this.phone,
//     this.walletBalance = 0.0,  // Default balance
//     DateTime? createdAt,       // Made optional
//   }) : createdAt = createdAt ?? DateTime.now();

//   factory Passenger.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>? ?? {};
//     return Passenger(
//       passengerId: data['passengerId']?.toString() ?? doc.id, // Fallback to doc ID
//       name: data['name']?.toString() ?? '',
//       email: data['email']?.toString() ?? '',
//       phone: data['phone']?.toString() ?? '',
//       walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
//     );
//   }

//   // For normal updates (excludes password)
//   Map<String, dynamic> toFirestore() {
//     return {
//       'passengerId': passengerId,
//       'name': name,
//       'email': email.toLowerCase().trim(), // Normalized email
//       'phone': phone.trim(),
//       'walletBalance': walletBalance,
//       'createdAt': Timestamp.fromDate(createdAt),
//     };
//   }


//   Passenger copyWith({
//     String? name,
//     String? email,
//     String? phone,
//     double? walletBalance,
//   }) {
//     return Passenger(
//       passengerId: passengerId,
//       name: name ?? this.name,
//       email: email ?? this.email,
//       phone: phone ?? this.phone,
//       walletBalance: walletBalance ?? this.walletBalance,
//       createdAt: createdAt,
//     );
//   }

// }