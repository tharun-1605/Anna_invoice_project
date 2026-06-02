import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  Company({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
