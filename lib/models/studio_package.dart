import 'package:cloud_firestore/cloud_firestore.dart';

class StudioPackage {
  StudioPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.items = const [],
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> items;

  factory StudioPackage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudioPackage(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      items: List<String>.from(data['items'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'items': items,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
