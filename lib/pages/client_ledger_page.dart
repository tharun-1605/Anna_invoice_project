import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/invoice.dart';
import '../utils/csv_exporter.dart';
import '../utils/formatters.dart';

class ClientLedgerPage extends StatefulWidget {
  const ClientLedgerPage({
    super.key,
    required this.clients,
    required this.invoices,
    this.initialClient,
  });

  final List<Client> clients;
  final List<Invoice> invoices;
  final Client? initialClient;

  @override
  State<ClientLedgerPage> createState() => _ClientLedgerPageState();
}

class _ClientLedgerPageState extends State<ClientLedgerPage> {
  Client? _selectedClient;
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.initialClient;
  }

  @override
  void didUpdateWidget(covariant ClientLedgerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialClient != oldWidget.initialClient) {
      setState(() {
        _selectedClient = widget.initialClient;
      });
    }
  }

  List<Invoice> get filteredInvoices {
    return widget.invoices.where((inv) {
      if (inv.type != 'Tax Invoice') return false;
      if (_selectedClient != null && inv.client.id != _selectedClient!.id) {
        return false;
      }
      if (_selectedMonth != null && inv.date.month != _selectedMonth) {
        return false;
      }
      if (_selectedYear != null && inv.date.year != _selectedYear) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    final history = filteredInvoices;
    final totalBilled = history.fold<double>(0, (sum, inv) => sum + inv.total);
    final totalPaid = history.fold<double>(0, (sum, inv) => sum + inv.paid);
    final balanceDue = history.fold<double>(0, (sum, inv) => sum + inv.due);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          clients: widget.clients,
          selectedClient: _selectedClient,
          onClientChanged: (c) => setState(() => _selectedClient = c),
          selectedMonth: _selectedMonth,
          onMonthChanged: (m) => setState(() => _selectedMonth = m),
          selectedYear: _selectedYear,
          onYearChanged: (y) => setState(() => _selectedYear = y),
          onExport: () => CsvExporter.exportInvoices(context, history),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            
            Widget metric1 = _MetricCard(
              label: 'Invoice Total',
              value: money.format(totalBilled),
              bgColor: Colors.white,
              textColor: const Color(0xFF111827),
              borderColor: const Color(0xFFF3F4F6),
            );
            Widget metric2 = _MetricCard(
              label: 'Paid',
              value: money.format(totalPaid),
              bgColor: const Color(0xFFF0FDF4),
              textColor: const Color(0xFF111827),
              labelColor: const Color(0xFF166534),
              borderColor: const Color(0xFFBBF7D0),
            );
            Widget metric3 = _MetricCard(
              label: 'Balance',
              value: money.format(balanceDue),
              bgColor: const Color(0xFFFEF2F2),
              textColor: const Color(0xFF111827),
              labelColor: const Color(0xFF991B1B),
              borderColor: const Color(0xFFFECACA),
            );

            if (isMobile) {
              return Column(
                children: [
                  metric1,
                  const SizedBox(height: 16),
                  metric2,
                  const SizedBox(height: 16),
                  metric3,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: metric1),
                const SizedBox(width: 16),
                Expanded(child: metric2),
                const SizedBox(width: 16),
                Expanded(child: metric3),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _LedgerTable(invoices: history),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    this.labelColor,
  });

  final String label;
  final String value;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? const Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.clients,
    required this.selectedClient,
    required this.onClientChanged,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.selectedYear,
    required this.onYearChanged,
    required this.onExport,
  });

  final List<Client> clients;
  final Client? selectedClient;
  final ValueChanged<Client?> onClientChanged;
  final int? selectedMonth;
  final ValueChanged<int?> onMonthChanged;
  final int? selectedYear;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        Widget headerTitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE7F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mail_outline, color: Color(0xFFBE185D), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Client Ledger',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Invoice totals, received payments, and pending balances by client.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );

        Widget filterClient = _FilterDropdown<Client>(
          label: 'Client',
          value: selectedClient,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Clients')),
            ...clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
          ],
          onChanged: onClientChanged,
        );

        Widget filterMonth = _FilterDropdown<int>(
          label: 'Month',
          value: selectedMonth,
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
            ...List.generate(12, (i) {
              final date = DateTime(2000, i + 1, 1);
              return DropdownMenuItem(value: i + 1, child: Text(dateFormatter.format(date).split(' ')[1]));
            }),
          ],
          onChanged: onMonthChanged,
        );

        Widget filterYear = _FilterDropdown<int>(
          label: 'Year',
          value: selectedYear,
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
            ...[2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
          ],
          onChanged: onYearChanged,
        );

        Widget exportBtn = FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE5E7EB),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export CSV'),
        );

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerTitle,
              const SizedBox(height: 16),
              filterClient,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: filterMonth),
                  const SizedBox(width: 12),
                  Expanded(child: filterYear),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: exportBtn),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 4, child: headerTitle),
            Expanded(flex: 2, child: filterClient),
            const SizedBox(width: 12),
            Expanded(child: filterMonth),
            const SizedBox(width: 12),
            Expanded(child: filterYear),
            const SizedBox(width: 16),
            exportBtn,
          ],
        );
      },
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T?>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 800,
            maxWidth: constraints.maxWidth > 800 ? constraints.maxWidth : 800,
          ),
          child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _HeaderCell('Client')),
                Expanded(child: _HeaderCell('Invoice')),
                Expanded(flex: 2, child: _HeaderCell('Date')),
                Expanded(child: _HeaderCell('Total', alignRight: true)),
                Expanded(child: _HeaderCell('Paid', alignRight: true)),
                Expanded(child: _HeaderCell('Balance', alignRight: true)),
                SizedBox(width: 80, child: _HeaderCell('Status')),
              ],
            ),
          ),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No invoices found for the selected filters.', style: TextStyle(color: Colors.black54)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final statusText = inv.due == 0 ? 'Paid' : (inv.paid > 0 ? 'Partial' : 'Unpaid');
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(inv.client.name, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(child: Text(inv.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 2, child: Text(dateFormatter.format(inv.date), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(child: Text(money.format(inv.total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(child: Text(money.format(inv.paid), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(child: Text(money.format(inv.due), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      SizedBox(width: 80, child: Text(statusText, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ),
      ),
    );
    });
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {this.alignRight = false});

  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.black,
      ),
    );
  }
}
