class InvoiceItem {
  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.price,
  });

  final String description;
  final double quantity;
  final double price;

  double get amount => quantity * price;

  factory InvoiceItem.fromJson(Map<String, dynamic> data) => InvoiceItem(
    description: data['description'] ?? '',
    quantity: (data['quantity'] ?? 0).toDouble(),
    price: (data['price'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'price': price,
    'amount': amount,
  };
}
