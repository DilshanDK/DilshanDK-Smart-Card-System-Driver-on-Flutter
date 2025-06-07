import 'package:cloud_firestore/cloud_firestore.dart';

class BusCompany {
  final String companyId;      // Business identifier
  final String companyName;    // Name of the bus company
  final double balance;        // Current account balance
  final DateTime createdAt;    // When company was registered
  final String accountNo;      // Bank account number

  BusCompany({
    required this.companyId,
    required this.companyName,
    required this.balance,
    required this.createdAt,
    required this.accountNo,
  });

  factory BusCompany.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BusCompany(
      companyId: data['companyId'] ?? doc.id, // Fallback to document ID
      companyName: data['companyName']?.toString() ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accountNo: data['accountNo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'accountNo': accountNo,
    };
  }

  // Helper method for updates
  BusCompany copyWith({
    String? companyId,
    String? companyName,
    double? balance,
    DateTime? createdAt,
    String? accountNo,
  }) {
    return BusCompany(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      accountNo: accountNo ?? this.accountNo,
    );
  }
}