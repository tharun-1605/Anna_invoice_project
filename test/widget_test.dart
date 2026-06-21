import 'package:flutter_test/flutter_test.dart';


import 'package:anna_invoice_project/models/company.dart';
import 'package:anna_invoice_project/models/client.dart';
import 'package:anna_invoice_project/models/invoice_item.dart';
import 'package:anna_invoice_project/models/invoice.dart';

void main() {
  test('invoice totals are calculated from items and paid amount', () {
    final invoice = Invoice(
      id: 'demo',
      number: '187',
      company: Company(
        id: 'company',
        name: 'ZA Pictures',
        address: 'Coimbatore',
        phone: '9003961109',
        email: 'hello@zapictures.in',
      ),
      client: Client(
        id: 'client',
        name: 'Pavithra',
        phone: '90035 87494',
        email: '',
        address: '',
      ),
      date: DateTime(2026, 6, 2),
      dueDate: DateTime(2026, 6, 9),
      items: [
        InvoiceItem(description: 'Wedding', quantity: 1, price: 130000),
        InvoiceItem(description: 'Reception', quantity: 1, price: 85000),
      ],
      paid: 50000,
      notes: '',
      createdAt: DateTime(2026, 6, 2),
      payments: [],
    );

    expect(invoice.subtotal, 215000);
    expect(invoice.total, 215000);
    expect(invoice.due, 165000);
  });

  test('invoice serialization handles shoot details correctly', () {
    final invoice = Invoice(
      id: 'demo_shoot',
      number: 'Q-2026',
      company: Company(
        id: 'company',
        name: 'ZA Pictures',
        address: 'Coimbatore',
        phone: '9003961109',
        email: 'hello@zapictures.in',
      ),
      client: Client(
        id: 'client',
        name: 'Pavithra',
        phone: '90035 87494',
        email: '',
        address: '',
      ),
      date: DateTime(2026, 6, 2),
      dueDate: DateTime(2026, 6, 9),
      items: [
        InvoiceItem(description: 'Wedding', quantity: 1, price: 130000),
      ],
      paid: 0,
      notes: '',
      createdAt: DateTime(2026, 6, 2),
      payments: [],
      shootType: 'Wedding',
      shootVenue: 'Rosewood Gardens',
      shootDate: DateTime(2026, 6, 12),
    );

    final json = invoice.toJson();
    expect(json['shootType'], 'Wedding');
    expect(json['shootVenue'], 'Rosewood Gardens');
    expect(json['shootDate'], isNotNull);
  });
}
