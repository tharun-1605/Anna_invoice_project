import 'package:cloud_firestore/cloud_firestore.dart';

class Lead {
  Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.eventDate = '',
    this.priority = 'Medium',
    this.reference = '',
    this.isRejected = false,
    this.rejectReason = '',
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String eventDate;
  final String priority;
  final String reference;
  final bool isRejected;
  final String rejectReason;

  factory Lead.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lead(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      eventDate: data['eventDate'] ?? '',
      priority: data['priority'] ?? 'Medium',
      reference: data['reference'] ?? '',
      isRejected: data['isRejected'] ?? false,
      rejectReason: data['rejectReason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'eventDate': eventDate,
    'priority': priority,
    'reference': reference,
    'isRejected': isRejected,
    'rejectReason': rejectReason,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lead && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
