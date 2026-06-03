import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../utils/csv_exporter.dart';
import '../utils/formatters.dart';


// I will define _FilterDropdown here to avoid exporting private classes from ledger.
class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.invoices});

  final List<Invoice> invoices;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  int? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  List<Invoice> get filteredInvoices {
    return widget.invoices.where((inv) {
      if (inv.type != 'Tax Invoice') return false;
      if (_selectedMonth != null && inv.date.month != _selectedMonth) return false;
      if (_selectedYear != null && inv.date.year != _selectedYear) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    final history = filteredInvoices;
    
    // Total Sales is sum of all invoice totals
    final totalSales = history.fold<double>(0, (sum, inv) => sum + inv.total);
    // Reverse-calculate 18% tax from total (Total = Subtotal + 18% Tax => Total = Subtotal * 1.18 => Subtotal = Total / 1.18, Tax = Total - Subtotal)
    final totalReportSubtotal = totalSales / 1.18;
    final totalTax = totalSales - totalReportSubtotal;

    final monthName = _selectedMonth != null 
        ? dateFormatter.format(DateTime(2000, _selectedMonth!, 1)).split(' ')[1] 
        : 'All Months';
    final yearName = _selectedYear != null ? _selectedYear.toString() : 'All Years';
    final subtitle = '$monthName $yearName';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
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
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bar_chart, color: Color(0xFF0369A1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sales',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            );

            Widget filterMonth = _FilterDropdown<int>(
              label: 'Month',
              value: _selectedMonth,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...List.generate(12, (i) {
                  final date = DateTime(2000, i + 1, 1);
                  return DropdownMenuItem(value: i + 1, child: Text(dateFormatter.format(date).split(' ')[1]));
                }),
              ],
              onChanged: (m) => setState(() => _selectedMonth = m),
            );

            Widget filterYear = _FilterDropdown<int>(
              label: 'Year',
              value: _selectedYear,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...[2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
              ],
              onChanged: (y) => setState(() => _selectedYear = y),
            );

            Widget exportBtn = FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _exportSalesCsv(context, history),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export CSV'),
            );

            Widget metric1 = _MetricCard(
              label: 'Invoices',
              value: history.length.toString(),
              bgColor: Colors.white,
              textColor: const Color(0xFF111827),
              borderColor: const Color(0xFFF3F4F6),
            );
            Widget metric2 = _MetricCard(
              label: 'Tax Amount',
              value: money.format(totalTax),
              bgColor: Colors.white,
              textColor: const Color(0xFF111827),
              labelColor: const Color(0xFF6B7280),
              borderColor: const Color(0xFFF3F4F6),
            );
            Widget metric3 = _MetricCard(
              label: 'Total Sales',
              value: money.format(totalSales),
              bgColor: const Color(0xFFF0FDF4),
              textColor: const Color(0xFF111827),
              labelColor: const Color(0xFF0F766E),
              borderColor: const Color(0xFFCCFBF1),
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerTitle,
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: filterMonth),
                      const SizedBox(width: 12),
                      Expanded(child: filterYear),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: exportBtn),
                  const SizedBox(height: 24),
                  metric1,
                  const SizedBox(height: 16),
                  metric2,
                  const SizedBox(height: 16),
                  metric3,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 4, child: headerTitle),
                    Expanded(child: filterMonth),
                    const SizedBox(width: 12),
                    Expanded(child: filterYear),
                    const SizedBox(width: 16),
                    exportBtn,
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: metric1),
                    const SizedBox(width: 16),
                    Expanded(child: metric2),
                    const SizedBox(width: 16),
                    Expanded(child: metric3),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _SalesTable(invoices: history, totalSubtotal: totalReportSubtotal, totalTax: totalTax, totalSales: totalSales),
      ],
    );
  }

  void _exportSalesCsv(BuildContext context, List<Invoice> history) {
    CsvExporter.exportSalesReport(history);
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

class _SalesTable extends StatelessWidget {
  const _SalesTable({
    required this.invoices,
    required this.totalSubtotal,
    required this.totalTax,
    required this.totalSales,
  });

  final List<Invoice> invoices;
  final double totalSubtotal;
  final double totalTax;
  final double totalSales;

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
                Expanded(flex: 2, child: _HeaderCell('Invoice No')),
                Expanded(flex: 2, child: _HeaderCell('Date')),
                Expanded(flex: 4, child: _HeaderCell('Client')),
                Expanded(flex: 2, child: _HeaderCell('Subtotal', alignRight: true)),
                Expanded(flex: 2, child: _HeaderCell('Tax', alignRight: true)),
                Expanded(flex: 2, child: _HeaderCell('Total', alignRight: true)),
              ],
            ),
          ),
          if (invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No sales found for the selected filters.', style: TextStyle(color: Colors.black54)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final reportSubtotal = inv.total / 1.18;
                final tax = inv.total - reportSubtotal;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(inv.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(flex: 2, child: Text(dateFormatter.format(inv.date), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(flex: 4, child: Text(inv.client.name, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(flex: 2, child: Text(money.format(reportSubtotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(flex: 2, child: Text(money.format(tax), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                      Expanded(flex: 2, child: Text(money.format(inv.total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    ],
                  ),
                );
              },
            ),
          if (invoices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 8, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Expanded(flex: 2, child: Text(money.format(totalSubtotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Expanded(flex: 2, child: Text(money.format(totalTax), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Expanded(flex: 2, child: Text(money.format(totalSales), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
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
