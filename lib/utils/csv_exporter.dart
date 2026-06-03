import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/invoice.dart';
import 'download_helper.dart';

class CsvExporter {
  static Future<void> exportInvoices(BuildContext context, List<Invoice> invoices) async {
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Headers
    List<List<dynamic>> rows = [
      [
        'Invoice Number',
        'Client Name',
        'Company Name',
        'Date',
        'Due Date',
        'Total',
        'Paid',
        'Balance',
        'Status',
        'Payment History',
        'Notes',
      ]
    ];

    for (final invoice in invoices) {
      final status = invoice.due == 0
          ? 'Paid'
          : invoice.paid > 0
              ? 'Partially Paid'
              : 'Unpaid';

      final paymentHistory = invoice.payments
          .map((p) => '${dateFormat.format(p.date)}: ${p.amount} (${p.method})')
          .join(' | ');

      rows.add([
        invoice.number,
        invoice.client.name,
        invoice.company.name,
        dateFormat.format(invoice.date),
        dateFormat.format(invoice.dueDate),
        invoice.total,
        invoice.paid,
        invoice.due,
        status,
        paymentHistory,
        invoice.notes.replaceAll('\n', ' '), // Keep notes on single line
      ]);
    }

    final csvString = csv.encode(rows);
    final bytes = Uint8List.fromList(csvString.codeUnits);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await DownloadHelper.saveFileWithPermission(
      context: context,
      name: 'invoices_$timestamp',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static Future<void> exportSalesReport(BuildContext context, List<Invoice> invoices) async {
    final dateFormat = DateFormat('yyyy-MM-dd');

    List<List<dynamic>> rows = [
      [
        'Invoice Number',
        'Date',
        'Client Name',
        'Subtotal',
        'Tax',
        'Total',
      ]
    ];

    double sumSubtotal = 0;
    double sumTax = 0;
    double sumTotal = 0;

    for (final invoice in invoices) {
      final reportSubtotal = invoice.total / 1.18;
      final tax = invoice.total - reportSubtotal;

      sumSubtotal += reportSubtotal;
      sumTax += tax;
      sumTotal += invoice.total;

      rows.add([
        invoice.number,
        dateFormat.format(invoice.date),
        invoice.client.name,
        reportSubtotal.toStringAsFixed(2),
        tax.toStringAsFixed(2),
        invoice.total.toStringAsFixed(2),
      ]);
    }

    // Add total row
    rows.add([]);
    rows.add([
      'TOTAL',
      '',
      '',
      sumSubtotal.toStringAsFixed(2),
      sumTax.toStringAsFixed(2),
      sumTotal.toStringAsFixed(2),
    ]);

    final csvString = csv.encode(rows);
    final bytes = Uint8List.fromList(csvString.codeUnits);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await DownloadHelper.saveFileWithPermission(
      context: context,
      name: 'sales_report_$timestamp',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }
}
