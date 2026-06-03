import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  Payment({
    required this.amount,
    required this.method,
    required this.date,
  });

  final double amount;
  final String method;
  final DateTime date;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      amount: (json['amount'] ?? 0).toDouble(),
      method: json['method'] ?? 'Unknown',
      date: _toDate(json['date']),
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'method': method,
        'date': Timestamp.fromDate(date),
      };

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
