import re

with open('lib/main.dart', 'r') as f:
    code = f.read()

replacement = """
class _InvoicesPage extends StatefulWidget {
  const _InvoicesPage({
    required this.invoices,
    required this.store,
    required this.onEdit,
  });

  final List<Invoice> invoices;
  final InvoiceStore store;
  final ValueChanged<Invoice> onEdit;

  @override
  State<_InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<_InvoicesPage> {
  final _searchCtrl = TextEditingController();
  String _selectedMonth = 'All';
  String _selectedYear = 'All';
  String _selectedStatus = 'All';
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  final List<String> _months = [
    'All', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _exportCsv() {
    CsvExporter.exportInvoices(widget.invoices);
  }

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
      
      if (_selectedYear != 'All') {
        if (inv.date.year.toString() != _selectedYear) return false;
      }
      
      if (inv.total < minAmt || inv.total > maxAmount) return false;

      if (_selectedStatus != 'All') {
        final status = inv.due == 0
            ? 'Paid'
            : inv.paid > 0
                ? 'Partially Paid'
                : 'Unpaid';
        if (status != _selectedStatus) return false;
      }

      return true;
    }).toList();

    final filteredTotal = filtered.fold<double>(0, (sum, inv) => sum + inv.total);
    final filteredPaid = filtered.fold<double>(0, (sum, inv) => sum + inv.paid);
    final filteredBalance = filtered.fold<double>(0, (sum, inv) => sum + inv.due);

    // Build year list dynamically
    final years = ['All', ...widget.invoices.map((e) => e.date.year.toString()).toSet().toList()..sort()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Saved Invoices',
          subtitle: 'Search, filter, reopen, and export your invoices.',
          action: FilledButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Filters',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _FilterField('Search', TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Invoice, client, company, amount',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _FilterField('Month', DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(isDense: true),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _selectedMonth = v!),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _FilterField('Year', DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: const InputDecoration(isDense: true),
                      items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (v) => setState(() => _selectedYear = v!),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _FilterField('Min Amount', TextField(
                      controller: _minCtrl,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) => setState(() {}),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _FilterField('Max Amount', TextField(
                      controller: _maxCtrl,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (_) => setState(() {}),
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _FilterField('Payment', DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(isDense: true),
                      items: ['All', 'Paid', 'Partially Paid', 'Unpaid'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                    )),
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
              child: _MetricCard('Filtered Total', _money.format(filteredTotal), Icons.receipt),
            ),
            Expanded(
              child: _MetricCard('Paid', _money.format(filteredPaid), Icons.check_circle_outline, color: Colors.green),
            ),
            Expanded(
              child: _MetricCard('Balance', _money.format(filteredBalance), Icons.account_balance_wallet, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 18),
        filtered.isEmpty
            ? const _EmptyState('No invoices match your filters')
            : Column(
                children: filtered.map((inv) => _InvoiceRow(
                  invoice: inv,
                  store: widget.store,
                  onEdit: () => widget.onEdit(inv),
                )).toList(),
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

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.store,
    required this.onEdit,
  });

  final Invoice invoice;
  final InvoiceStore store;
  final VoidCallback onEdit;

  Future<void> _addPayment(BuildContext context) async {
    final ctrl = TextEditingController();
    await showDialog(
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

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.due == 0;
    final isPartiallyPaid = invoice.paid > 0 && invoice.due > 0;
    
    final statusColor = isPaid ? Colors.green : (isPartiallyPaid ? Colors.orange : Colors.red);
    final statusText = isPaid ? 'Paid' : (isPartiallyPaid ? 'Partially Paid' : 'Unpaid');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  '${invoice.number}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text('Client: ${invoice.client.name}', style: const TextStyle(color: Colors.black87)),
                Text('Company: ${invoice.company.name}', style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 6),
                Text('Date: ${_date.format(invoice.date)}', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total', style: TextStyle(color: Colors.black54, fontSize: 12)),
                Text(_money.format(invoice.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
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
                Text(_money.format(invoice.paid), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Balance', style: TextStyle(color: Colors.black54, fontSize: 12)),
                Text(_money.format(invoice.due), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () { /* View is implicitly available via Edit/Download for now */ },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () => exportPdf(invoice),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download PDF'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Invoice'),
                ),
                TextButton.icon(
                  onPressed: () => _addPayment(context),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Add Payment'),
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
"""

start_idx = code.find('class _InvoicesPage extends StatelessWidget {')
end_idx = code.find('class _StatusLine extends StatelessWidget {')

if start_idx != -1 and end_idx != -1:
    new_code = code[:start_idx] + replacement + code[end_idx:]
    with open('lib/main.dart', 'w') as f:
        f.write(new_code)
        
    print("Replaced _InvoicesPage and _InvoiceRow")
else:
    print("Could not find start or end index!")
