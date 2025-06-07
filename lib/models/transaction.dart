import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String transactionId;  // Firestore document ID
  final String passengerId;    // Reference to passenger
  final String companyId;      // Reference to bus company
  final double amount;        // Positive transaction amount
  final String journeyId;      // Associated journey
  final DateTime timestamp;    // Transaction time
  final String status;        // Transaction state

  Transaction({
    required this.transactionId,
    required this.passengerId,
    required this.companyId,
    required this.amount,
    required this.journeyId,
    DateTime? timestamp,
    this.status = 'pending',
  }) : timestamp = timestamp ?? DateTime.now(),
       assert(amount >= 0, 'Transaction amount cannot be negative');

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Transaction(
      transactionId: doc.id,
      passengerId: data['passengerId']?.toString() ?? data['userId']?.toString() ?? '',
      companyId: data['companyId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.abs().toDouble() ?? 0.0,
      journeyId: data['journeyId']?.toString() ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _validateStatus(data['status']?.toString()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'companyId': companyId,
      'amount': amount,
      'journeyId': journeyId,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  // Helper methods
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  static String _validateStatus(String? status) {
    const validStatuses = ['pending', 'completed', 'failed', 'refunded'];
    return validStatuses.contains(status?.toLowerCase()) ? status!.toLowerCase() : 'pending';
  }

  Transaction copyWith({
    String? status,
    double? amount,
  }) {
    return Transaction(
      transactionId: transactionId,
      passengerId: passengerId,
      companyId: companyId,
      amount: amount ?? this.amount,
      journeyId: journeyId,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }
}