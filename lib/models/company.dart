import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  Company({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    this.signatureBase64 = '',
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String signatureBase64;

  factory Company.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      signatureBase64: data['signatureBase64'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'signatureBase64': signatureBase64,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Company && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
