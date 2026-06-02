import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/invoice.dart';
import 'formatters.dart';

const logoPath = 'assets/images/za_logo.png';

Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
  final logoBytes = await rootBundle.load(logoPath);
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(36),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 170),
            pw.Spacer(),
            pw.Text(
              'Invoice',
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _pdfAddress(invoice.company.name, [
                invoice.company.address,
                invoice.company.phone,
                invoice.company.email,
              ]),
            ),
            pw.Expanded(
              child: _pdfAddress('BILL TO', [
                invoice.client.name,
                invoice.client.phone,
                invoice.client.email,
                invoice.client.address,
              ]),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _pdfFact('Invoice #', invoice.number),
                  _pdfFact('Date', dateFormatter.format(invoice.date)),
                  _pdfFact('Due date', dateFormatter.format(invoice.dueDate)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Quantity', 'Price', 'Amount'],
          data: invoice.items
              .map(
                (item) => [
                  item.description,
                  item.quantity.toStringAsFixed(0),
                  money.format(item.price),
                  money.format(item.amount),
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.topLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(5),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
        ),
        pw.SizedBox(height: 18),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                _pdfTotal('Subtotal', money.format(invoice.subtotal)),
                _pdfTotal('Total', money.format(invoice.total), strong: true),
                _pdfTotal('Paid', money.format(invoice.paid)),
                pw.Divider(),
                _pdfTotal(
                  'Amount Due',
                  money.format(invoice.due),
                  strong: true,
                ),
              ],
            ),
          ),
        ),
        if (invoice.notes.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          pw.Text(invoice.notes),
        ],
      ],
    ),
  );

  return doc.save();
}

pw.Widget _pdfAddress(String title, List<String> lines) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      ...lines.where((line) => line.trim().isNotEmpty).map(pw.Text.new),
    ],
  );
}

pw.Widget _pdfFact(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _pdfTotal(String label, String value, {bool strong = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      children: [
        pw.Text(label),
        pw.Spacer(),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
