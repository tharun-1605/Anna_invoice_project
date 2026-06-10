import 'package:cloud_firestore/cloud_firestore.dart';

class Client {
  Client({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.fromLead = false,
    this.eventDate = '',
    this.priority = 'Medium',
    this.reference = '',
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final bool fromLead;
  final String eventDate;
  final String priority;
  final String reference;

  factory Client.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Client(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      fromLead: data['fromLead'] ?? false,
      eventDate: data['eventDate'] ?? '',
      priority: data['priority'] ?? 'Medium',
      reference: data['reference'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'updatedAt': FieldValue.serverTimestamp(),
    'fromLead': fromLead,
    'eventDate': eventDate,
    'priority': priority,
    'reference': reference,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
