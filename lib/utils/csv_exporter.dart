import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';

class CsvExporter {
  static Future<void> exportInvoices(List<Invoice> invoices) async {
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
        'Notes',
      ]
    ];

    for (final invoice in invoices) {
      final status = invoice.due == 0
          ? 'Paid'
          : invoice.paid > 0
              ? 'Partially Paid'
              : 'Unpaid';

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
        invoice.notes.replaceAll('\n', ' '), // Keep notes on single line
      ]);
    }

    final csvString = csv.encode(rows);
    final bytes = Uint8List.fromList(csvString.codeUnits);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await FileSaver.instance.saveFile(
      name: 'invoices_$timestamp',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }
}
