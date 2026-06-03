import 'package:cloud_firestore/cloud_firestore.dart';
import 'company.dart';
import 'client.dart';
import 'invoice_item.dart';
import 'payment.dart';

class Invoice {
  Invoice({
    required this.id,
    required this.number,
    required this.company,
    required this.client,
    required this.date,
    required this.dueDate,
    required this.items,
    required this.paid,
    required this.notes,
    required this.createdAt,
    required this.payments,
    this.discountPercentage = 0.0,
    this.type = 'Tax Invoice',
    this.isReminderDismissed = false,
  });

  final String id;
  final String number;
  final Company company;
  final Client client;
  final DateTime date;
  final DateTime dueDate;
  final List<InvoiceItem> items;
  final double paid;
  final String notes;
  final DateTime createdAt;
  final double discountPercentage;
  final String type;
  final List<Payment> payments;
  final bool isReminderDismissed;

  double get subtotal => items.fold(0, (total, item) => total + item.amount);
  double get discountAmount => subtotal * (discountPercentage / 100);
  double get total => subtotal - discountAmount;
  double get due => (total - paid).clamp(0, double.infinity);

  factory Invoice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final companyData = Map<String, dynamic>.from(data['company'] ?? {});
    final clientData = Map<String, dynamic>.from(data['client'] ?? {});
    
    final paidAmount = (data['paid'] ?? 0).toDouble();
    List<Payment> parsedPayments = (data['payments'] as List<dynamic>? ?? [])
        .map((p) => Payment.fromJson(Map<String, dynamic>.from(p)))
        .toList();
        
    // Legacy migration
    if (parsedPayments.isEmpty && paidAmount > 0) {
      parsedPayments = [
        Payment(
          amount: paidAmount,
          method: 'Legacy Payment',
          date: _toDate(data['createdAt']),
        )
      ];
    }
    
    return Invoice(
      id: doc.id,
      number: data['number'] ?? '',
      company: Company(
        id: companyData['id'] ?? '',
        name: companyData['name'] ?? '',
        address: companyData['address'] ?? '',
        phone: companyData['phone'] ?? '',
        email: companyData['email'] ?? '',
      ),
      client: Client(
        id: clientData['id'] ?? '',
        name: clientData['name'] ?? '',
        phone: clientData['phone'] ?? '',
        email: clientData['email'] ?? '',
        address: clientData['address'] ?? '',
      ),
      date: _toDate(data['date']),
      dueDate: _toDate(data['dueDate']),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => InvoiceItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      paid: paidAmount,
      discountPercentage: (data['discountPercentage'] ?? 0).toDouble(),
      notes: data['notes'] ?? '',
      createdAt: _toDate(data['createdAt']),
      type: data['type'] ?? 'Tax Invoice',
      payments: parsedPayments,
      isReminderDismissed: data['isReminderDismissed'] ?? false,
    );
  }

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'company': {
      'id': company.id,
      'name': company.name,
      'address': company.address,
      'phone': company.phone,
      'email': company.email,
    },
    'client': {
      'id': client.id,
      'name': client.name,
      'phone': client.phone,
      'email': client.email,
      'address': client.address,
    },
    'date': Timestamp.fromDate(date),
    'dueDate': Timestamp.fromDate(dueDate),
    'items': items.map((item) => item.toJson()).toList(),
    'subtotal': subtotal,
    'discountPercentage': discountPercentage,
    'total': total,
    'paid': paid,
    'amountDue': due,
    'notes': notes,
    'createdAt': FieldValue.serverTimestamp(),
    'type': type,
    'payments': payments.map((p) => p.toJson()).toList(),
    'isReminderDismissed': isReminderDismissed,
  };
}
