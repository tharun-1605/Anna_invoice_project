import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/invoice.dart';
import '../services/invoice_store.dart';
import '../utils/csv_exporter.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import '../widgets/common_widgets.dart';

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

  Future<void> _exportCsv() => CsvExporter.exportInvoices(widget.invoices);

  @override
  Widget build(BuildContext context) {
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
    }).toList();

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
          child: Column(
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
                        items: _months
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
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
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
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
                        items: ['All', 'Paid', 'Partially Paid', 'Unpaid']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
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
        Row(
          children: [
            Expanded(
              child: MetricCard('Filtered Total', money.format(filteredTotal), Icons.receipt),
            ),
            Expanded(
              child: MetricCard(
                'Paid',
                money.format(filteredPaid),
                Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
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
        filtered.isEmpty
            ? const EmptyState('No invoices match your filters')
            : Column(
                children: filtered
                    .map(
                      (inv) => InvoiceActionRow(
                        invoice: inv,
                        store: widget.store,
                        onEdit: () => widget.onEdit(inv),
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
  });

  final Invoice invoice;
  final InvoiceStore store;
  final VoidCallback onEdit;

  Future<void> _addPayment(BuildContext context) async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text) ?? 0;
              if (amount > 0) {
                final updated = Invoice(
                  id: invoice.id,
                  number: invoice.number,
                  company: invoice.company,
                  client: invoice.client,
                  date: invoice.date,
                  dueDate: invoice.dueDate,
                  items: invoice.items,
                  paid: invoice.paid + amount,
                  notes: invoice.notes,
                  createdAt: invoice.createdAt,
                );
                await store.saveInvoice(updated);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
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

  Future<void> _downloadPdf() async {
    final bytes = await buildInvoicePdf(invoice);
    await Printing.layoutPdf(
      name: 'invoice-${invoice.number}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.due == 0
        ? Colors.green
        : (invoice.paid > 0 ? Colors.orange : Colors.red);
    final statusText = _invoiceStatus(invoice);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
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
                Text(
                  'Date: ${dateFormatter.format(invoice.date)}',
                  style: const TextStyle(color: Colors.black54),
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
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _addPayment(context),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Payment'),
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
    );
  }
}

String _invoiceStatus(Invoice invoice) {
  if (invoice.due == 0) return 'Paid';
  if (invoice.paid > 0) return 'Partially Paid';
  return 'Unpaid';
}
