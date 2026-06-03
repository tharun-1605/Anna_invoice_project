import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import 'formatters.dart';

const logoPath = 'assets/images/za_logo.png';

Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
  final logoBytes = await rootBundle.load(logoPath);
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final doc = pw.Document();

  final font = await PdfGoogleFonts.robotoRegular();
  final boldFont = await PdfGoogleFonts.robotoBold();

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 170),
            pw.Spacer(),
            pw.Text(
              invoice.type.toUpperCase(),
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
                  _pdfFact('${invoice.type} #', invoice.number),
                  _pdfFact('Date', dateFormatter.format(invoice.date)),
                  _pdfFact('Due date', dateFormatter.format(invoice.dueDate)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.Table(
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            left: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            right: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(5),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.black),
              children: [
                _pdfHeader('Item'),
                _pdfHeader('Quantity'),
                _pdfHeader('Price'),
                _pdfHeader('Amount'),
              ],
            ),
            ...invoice.items.map((item) {
              final lines = item.description.split('\n');
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          lines.first,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        if (lines.length > 1) pw.SizedBox(height: 3),
                        if (lines.length > 1)
                          ...lines.skip(1).map(
                                (line) => pw.Text(
                                  line,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                      ],
                    ),
                  ),
                  _pdfCell(item.quantity.toStringAsFixed(0)),
                  _pdfCell(money.format(item.price)),
                  _pdfCell(money.format(item.amount)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(
              children: [
                _pdfTotal('Subtotal', money.format(invoice.subtotal)),
                if (invoice.discountPercentage > 0)
                  _pdfTotal('Discount (${invoice.discountPercentage.toStringAsFixed(0)}%)', '-${money.format(invoice.discountAmount)}'),
                _pdfTotal('Total', money.format(invoice.total), strong: true),
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

pw.Widget _pdfHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 10,
      ),
    ),
  );
}

pw.Widget _pdfCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 10),
    ),
  );
}

Future<Uint8List> buildLedgerPdf(
  Client client,
  List<Invoice> history,
  double billed,
  double paid,
  double due,
) async {
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
              'Statement of Account',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 28),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _pdfAddress('CLIENT', [
                client.name,
                client.phone,
                client.email,
                client.address,
              ]),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _pdfFact('Date Generated', dateFormatter.format(DateTime.now())),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _pdfFact('Total Billed', money.format(billed)),
            _pdfFact('Total Paid', money.format(paid)),
            _pdfFact('Balance Due', money.format(due)),
          ],
        ),
        pw.SizedBox(height: 26),
        pw.Table(
          border: const pw.TableBorder(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            left: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            right: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            verticalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.black),
              children: [
                _pdfHeader('Invoice #'),
                _pdfHeader('Date'),
                _pdfHeader('Total'),
                _pdfHeader('Paid'),
                _pdfHeader('Balance'),
              ],
            ),
            ...history.map((inv) {
              return pw.TableRow(
                children: [
                  _pdfCell(inv.number),
                  _pdfCell(dateFormatter.format(inv.date)),
                  _pdfCell(money.format(inv.total)),
                  _pdfCell(money.format(inv.paid)),
                  _pdfCell(money.format(inv.due)),
                ],
              );
            }),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}
