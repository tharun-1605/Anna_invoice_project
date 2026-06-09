import 'package:cloud_firestore/cloud_firestore.dart';

class StudioItem {
  StudioItem({
    required this.id,
    required this.name,
    required this.price,
  });

  final String id;
  final String name;
  final double price;

  factory StudioItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StudioItem(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudioItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
