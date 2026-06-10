import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice.dart';
import '../models/payment.dart';
import '../services/invoice_store.dart';
import '../utils/csv_exporter.dart';
import '../utils/download_helper.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import '../widgets/common_widgets.dart';
import 'package:file_saver/file_saver.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({
    super.key,
    required this.invoices,
    required this.store,
    required this.onEdit,
  });

  final List<Invoice> invoices;
  final InvoiceStore store;
  final ValueChanged<Invoice> onEdit;

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  String _selectedMonth = 'All';
  String _selectedYear = 'All';
  String _selectedStatus = 'All';
  Set<String> _selectedIds = {};

  Future<void> _bulkExport() async {
    final selectedInvoices = widget.invoices.where((i) => _selectedIds.contains(i.id)).toList();
    if (selectedInvoices.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final bytes = await buildCombinedInvoicePdf(selectedInvoices);
      if (!mounted) return;
      Navigator.of(context).pop();

      await DownloadHelper.saveFileWithPermission(
        context: context,
        name: 'bulk-invoices-${DateTime.now().millisecondsSinceEpoch}',
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    }
  }

  Future<void> _bulkDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Invoices?'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} invoices? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      for (final id in _selectedIds) {
        await widget.store.deleteInvoice(id);
      }
      setState(() {
        _selectedIds.clear();
      });
    }
  }

  final List<String> _months = [
    'All',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() => CsvExporter.exportInvoices(context, widget.invoices);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final query = _searchCtrl.text.toLowerCase();
    final minAmt = double.tryParse(_minCtrl.text) ?? 0.0;
    final maxAmt = double.tryParse(_maxCtrl.text) ?? double.infinity;
    final maxAmount = maxAmt <= 0 ? double.infinity : maxAmt;

    final filtered = widget.invoices.where((inv) {
      if (query.isNotEmpty) {
        final matches = inv.number.toLowerCase().contains(query) ||
            inv.client.name.toLowerCase().contains(query) ||
            inv.company.name.toLowerCase().contains(query) ||
            inv.total.toString().contains(query);
        if (!matches) return false;
      }

      if (_selectedMonth != 'All') {
        final monthStr = _months[inv.date.month];
        if (monthStr != _selectedMonth) return false;
      }

      if (_selectedYear != 'All' && inv.date.year.toString() != _selectedYear) {
        return false;
      }

      if (inv.total < minAmt || inv.total > maxAmount) return false;

      if (_selectedStatus != 'All' && _invoiceStatus(inv) != _selectedStatus) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final numA = int.tryParse(a.number);
        final numB = int.tryParse(b.number);
        if (numA != null && numB != null) {
          return numB.compareTo(numA); // descending
        }
        return b.number.compareTo(a.number); // descending
      });

    final filteredTotal = filtered.fold<double>(0, (sum, inv) => sum + inv.total);
    final filteredPaid = filtered.fold<double>(0, (sum, inv) => sum + inv.paid);
    final filteredBalance = filtered.fold<double>(0, (sum, inv) => sum + inv.due);
    final years = [
      'All',
      ...widget.invoices.map((e) => e.date.year.toString()).toSet().toList()..sort(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Saved Invoices',
          subtitle: 'Search, filter, reopen, and export your invoices.',
          action: FilledButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          title: 'Filters',
          child: isMobile
              ? Column(
                  children: [
                    _FilterField(
                      'Search',
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Invoice, client, company, amount',
                          prefixIcon: Icon(Icons.search, size: 20),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            'Month',
                            DropdownButtonFormField<String>(
                              initialValue: _selectedMonth,
                              decoration: const InputDecoration(isDense: true),
                              items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (v) => setState(() => _selectedMonth = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Year',
                            DropdownButtonFormField<String>(
                              initialValue: _selectedYear,
                              decoration: const InputDecoration(isDense: true),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (v) => setState(() => _selectedYear = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            'Min Amount',
                            TextField(
                              controller: _minCtrl,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Max Amount',
                            TextField(
                              controller: _maxCtrl,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FilterField(
                      'Payment',
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(isDense: true),
                        items: ['All', 'Paid', 'Partially Paid', 'Unpaid'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _FilterField(
                            'Search',
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Invoice, client, company, amount',
                                prefixIcon: Icon(Icons.search, size: 20),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Month',
                            DropdownButtonFormField<String>(
                              initialValue: _selectedMonth,
                              decoration: const InputDecoration(isDense: true),
                              items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (v) => setState(() => _selectedMonth = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Year',
                            DropdownButtonFormField<String>(
                              initialValue: _selectedYear,
                              decoration: const InputDecoration(isDense: true),
                              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (v) => setState(() => _selectedYear = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Min Amount',
                            TextField(
                              controller: _minCtrl,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FilterField(
                            'Max Amount',
                            TextField(
                              controller: _maxCtrl,
                              decoration: const InputDecoration(isDense: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterField(
                            'Payment',
                            DropdownButtonFormField<String>(
                              initialValue: _selectedStatus,
                              decoration: const InputDecoration(isDense: true),
                              items: ['All', 'Paid', 'Partially Paid', 'Unpaid'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _selectedStatus = v!),
                            ),
                          ),
                        ),
                        const Spacer(flex: 4),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        isMobile
            ? Column(
                children: [
                  MetricCard('Filtered Total', money.format(filteredTotal), Icons.receipt),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          'Paid',
                          money.format(filteredPaid),
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricCard(
                          'Balance',
                          money.format(filteredBalance),
                          Icons.account_balance_wallet,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: MetricCard('Filtered Total', money.format(filteredTotal), Icons.receipt),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      'Paid',
                      money.format(filteredPaid),
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      'Balance',
                      money.format(filteredBalance),
                      Icons.account_balance_wallet,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 18),
        if (_selectedIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _bulkExport,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Export PDF'),
                ),
                TextButton.icon(
                  onPressed: _bulkDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        filtered.isEmpty
            ? const EmptyState('No invoices match your filters')
            : Column(
                children: filtered
                    .map(
                      (inv) => InvoiceActionRow(
                        invoice: inv,
                        store: widget.store,
                        onEdit: () => widget.onEdit(inv),
                        isSelected: _selectedIds.contains(inv.id),
                        onSelectChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(inv.id);
                            } else {
                              _selectedIds.remove(inv.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField(this.label, this.child);

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class InvoiceActionRow extends StatelessWidget {
  const InvoiceActionRow({
    super.key,
    required this.invoice,
    required this.store,
    required this.onEdit,
    this.isSelected = false,
    this.onSelectChanged,
  });

  final Invoice invoice;
  final InvoiceStore store;
  final VoidCallback onEdit;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectChanged;

  Future<void> _managePayments(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ManagePaymentsDialog(invoice: invoice, store: store),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: const Text('Are you sure you want to delete this invoice? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await store.deleteInvoice(invoice.id);
    }
  }

  Future<void> _downloadPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    Uint8List? bytes;
    try {
      bytes = await buildInvoicePdf(invoice);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    await DownloadHelper.saveFileWithPermission(
      context: context,
      name: 'invoice-${invoice.number}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  void _viewPdf(BuildContext context) {
    final pdfFuture = buildInvoicePdf(invoice);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Invoice ${invoice.number}')),
          body: PdfPreview(
            build: (format) => pdfFuture,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    Uint8List? bytes;
    try {
      bytes = await buildInvoicePdf(invoice);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    try {
      if (kIsWeb) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'application/pdf', name: 'Invoice-${invoice.number}.pdf')],
          text: 'Here is the invoice for ${invoice.client.name}',
          subject: 'Invoice ${invoice.number}',
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/Invoice-${invoice.number}.pdf');
        await file.writeAsBytes(bytes);
        
        if (context.mounted) {
          final box = context.findRenderObject() as RenderBox?;
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Here is the invoice for ${invoice.client.name}',
            subject: 'Invoice ${invoice.number}',
            sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  Future<void> _convertToTaxInvoice(BuildContext context) async {
    final updated = Invoice(
      id: invoice.id,
      number: invoice.number,
      company: invoice.company,
      client: invoice.client,
      date: invoice.date,
      dueDate: invoice.dueDate,
      items: invoice.items,
      paid: invoice.paid,
      discountAmount: invoice.discountAmount,
      notes: invoice.notes,
      createdAt: invoice.createdAt,
      type: 'Tax Invoice',
      payments: invoice.payments,
    );
    await store.saveInvoice(updated);
  }

  Future<void> _sendReminder(BuildContext context) async {
    final text = 'Hello ${invoice.client.name}, this is a reminder that Invoice ${invoice.number} for ${money.format(invoice.total)} is due on ${dateFormatter.format(invoice.dueDate)}. The current balance is ${money.format(invoice.due)}. Please arrange payment. Thank you!';
    final phone = invoice.client.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('whatsapp://send?phone=$phone&text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.due == 0
        ? Colors.green
        : (invoice.paid > 0 ? Colors.orange : Colors.red);
    final statusText = _invoiceStatus(invoice);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onSelectChanged != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Checkbox(value: isSelected, onChanged: onSelectChanged),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.number,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text('Client: ${invoice.client.name}', style: const TextStyle(color: Colors.black87)),
                          Text('Company: ${invoice.company.name}', style: const TextStyle(color: Colors.black87)),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Date: ${dateFormatter.format(invoice.date)}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              if (invoice.type != 'Tax Invoice') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    invoice.type,
                                    style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          Text(money.format(invoice.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Paid', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          Text(money.format(invoice.paid), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Balance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                          Text(money.format(invoice.due), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _viewPdf(context),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _downloadPdf(context),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _sharePdf(context),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Share'),
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                    if (invoice.type == 'Tax Invoice' && invoice.due > 0)
                      TextButton.icon(
                        onPressed: () => _managePayments(context),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Payment'),
                      ),
                    if (invoice.type != 'Tax Invoice')
                      TextButton.icon(
                        onPressed: () => _convertToTaxInvoice(context),
                        icon: const Icon(Icons.transform, size: 16),
                        label: const Text('Convert to Tax'),
                      ),
                    if (invoice.type == 'Tax Invoice' && invoice.due > 0 && DateTime.now().isAfter(invoice.dueDate))
                      TextButton.icon(
                        onPressed: () => _sendReminder(context),
                        icon: const Icon(Icons.notifications_active, size: 16, color: Colors.green),
                        label: const Text('Reminder', style: TextStyle(color: Colors.green)),
                      ),
                    TextButton.icon(
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.number,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text('Client: ${invoice.client.name}', style: const TextStyle(color: Colors.black87)),
                      Text('Company: ${invoice.company.name}', style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Date: ${dateFormatter.format(invoice.date)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (invoice.type != 'Tax Invoice') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                invoice.type,
                                style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      Text(money.format(invoice.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      Text(money.format(invoice.paid), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                      Text(money.format(invoice.due), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _viewPdf(context),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _downloadPdf(context),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () => _sharePdf(context),
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                      if (invoice.type == 'Tax Invoice' && invoice.due > 0)
                        TextButton.icon(
                          onPressed: () => _managePayments(context),
                          icon: const Icon(Icons.payment, size: 16),
                          label: const Text('Payment'),
                        ),
                      if (invoice.type != 'Tax Invoice')
                        TextButton.icon(
                          onPressed: () => _convertToTaxInvoice(context),
                          icon: const Icon(Icons.transform, size: 16),
                          label: const Text('Convert to Tax'),
                        ),
                      if (invoice.type == 'Tax Invoice' && invoice.due > 0 && DateTime.now().isAfter(invoice.dueDate))
                        TextButton.icon(
                          onPressed: () => _sendReminder(context),
                          icon: const Icon(Icons.notifications_active, size: 16, color: Colors.green),
                          label: const Text('Reminder', style: TextStyle(color: Colors.green)),
                        ),
                      TextButton.icon(
                        onPressed: () => _delete(context),
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invoice.payments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: invoice.payments.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(dateFormatter.format(p.date), style: const TextStyle(fontSize: 13))),
                          Expanded(child: Text(p.method, style: const TextStyle(fontSize: 13, color: Colors.black54))),
                          Expanded(
                            child: Text(
                              money.format(p.amount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);
  }
}

String _invoiceStatus(Invoice invoice) {
  if (invoice.due == 0) return 'Paid';
  if (invoice.paid > 0) return 'Partially Paid';
  return 'Unpaid';
}

class ManagePaymentsDialog extends StatefulWidget {
  const ManagePaymentsDialog({super.key, required this.invoice, required this.store});
  final Invoice invoice;
  final InvoiceStore store;

  @override
  State<ManagePaymentsDialog> createState() => _ManagePaymentsDialogState();
}

class _ManagePaymentsDialogState extends State<ManagePaymentsDialog> {
  late List<Payment> payments;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    payments = List.from(widget.invoice.payments);
  }

  void _addPayment() {
    final currentDue = widget.invoice.total - payments.fold(0.0, (s, p) => s + p.amount);
    if (currentDue <= 0) return;
    setState(() {
      payments.add(Payment(amount: currentDue, method: 'Cash', date: DateTime.now()));
    });
  }

  Future<void> _save() async {
    setState(() => isSaving = true);
    final totalPaid = payments.fold(0.0, (s, p) => s + p.amount);
    final updated = Invoice(
      id: widget.invoice.id,
      number: widget.invoice.number,
      company: widget.invoice.company,
      client: widget.invoice.client,
      date: widget.invoice.date,
      dueDate: widget.invoice.dueDate,
      items: widget.invoice.items,
      paid: totalPaid,
      discountAmount: widget.invoice.discountAmount,
      notes: widget.invoice.notes,
      createdAt: widget.invoice.createdAt,
      type: widget.invoice.type,
      payments: payments,
    );
    try {
      await widget.store.saveInvoice(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = ['Cash', 'Card', 'Bank Transfer', 'GPay', 'UPI', 'Cheque'];
    final currentDue = widget.invoice.total - payments.fold(0.0, (s, p) => s + p.amount);
    
    return AlertDialog(
      title: const Text('Manage Payments'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payments.isEmpty) const Text('No payments yet.'),
              for (int i = 0; i < payments.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: payments[i].amount.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount', isDense: true),
                          onChanged: (val) {
                            payments[i] = Payment(
                              amount: double.tryParse(val) ?? 0,
                              method: payments[i].method,
                              date: payments[i].date,
                            );
                            setState(() {}); // update due amount
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: payments[i].method,
                          decoration: const InputDecoration(labelText: 'Method', isDense: true),
                          items: {
                            ...methods,
                            if (!methods.contains(payments[i].method)) payments[i].method
                          }.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                payments[i] = Payment(
                                  amount: payments[i].amount,
                                  method: val,
                                  date: payments[i].date,
                                );
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: payments[i].date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() {
                                payments[i] = Payment(
                                  amount: payments[i].amount,
                                  method: payments[i].method,
                                  date: date,
                                );
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date', isDense: true),
                            child: Text(dateFormatter.format(payments[i].date)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Installment',
                        onPressed: () {
                          setState(() {
                            payments.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (currentDue > 0)
                OutlinedButton.icon(
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add),
                  label: Text('Add Installment (Due: ${currentDue.toStringAsFixed(2)})'),
                ),
              if (currentDue <= 0 && payments.isNotEmpty)
                const Text('Invoice is fully paid.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Payments'),
        ),
      ],
    );
  }
}
