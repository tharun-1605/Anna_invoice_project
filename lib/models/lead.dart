import 'package:cloud_firestore/cloud_firestore.dart';

class Lead {
  Lead({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;

  factory Lead.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Lead(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
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
