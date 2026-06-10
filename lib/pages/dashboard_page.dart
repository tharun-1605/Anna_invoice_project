import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/studio_package.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/compact_invoice_row.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.invoices,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.loading,
    required this.onCreate,
  });

  final List<Invoice> invoices;
  final List<Company> companies;
  final List<Client> clients;
  final List<StudioPackage> packages;
  final bool loading;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final total = invoices.fold<double>(
      0,
      (runningTotal, invoice) => runningTotal + invoice.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Dashboard',
          subtitle: 'Create, save, and export ZA Pictures invoices.',
          action: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create invoice'),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 18),
        ResponsiveGrid(
          children: [
            MetricCard('Invoices', invoices.length.toString(), Icons.receipt_long),
            MetricCard('Clients', clients.length.toString(), Icons.people),
            MetricCard('Packages', packages.length.toString(), Icons.inventory_2),
            MetricCard('Revenue', money.format(total), Icons.trending_up),
          ],
        ),
        const SizedBox(height: 22),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            final recentInvoices = Panel(
              title: 'Recent invoices',
              child: invoices.isEmpty
                  ? const EmptyState('No invoices yet')
                  : Column(
                      children: invoices.take(6).map(CompactInvoiceRow.new).toList(),
                    ),
            );
            
            final revenueChart = _RevenueChart(invoices: invoices);
            final pieChart = _PaymentPieChart(invoices: invoices);
            final topClients = _TopClientsList(invoices: invoices);

            if (isMobile) {
              return Column(
                children: [
                  revenueChart,
                  const SizedBox(height: 18),
                  pieChart,
                  const SizedBox(height: 18),
                  topClients,
                  const SizedBox(height: 18),
                  recentInvoices,
                ],
              );
            }
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: revenueChart),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: pieChart),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recentInvoices),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: topClients),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    final Map<int, double> monthlyRevenue = {};
    for (final inv in invoices) {
      if (inv.date.year == DateTime.now().year) {
        monthlyRevenue[inv.date.month] = (monthlyRevenue[inv.date.month] ?? 0) + inv.total;
      }
    }

    final spots = <FlSpot>[];
    for (int i = 1; i <= 12; i++) {
      spots.add(FlSpot(i.toDouble(), monthlyRevenue[i] ?? 0));
    }

    return Panel(
      title: 'Revenue (${DateTime.now().year})',
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final idx = value.toInt() - 1;
                    if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                    return Text(months[idx], style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  const _PaymentPieChart({required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();
    
    final paid = invoices.fold<double>(0, (sum, inv) => sum + inv.paid);
    final due = invoices.fold<double>(0, (sum, inv) => sum + inv.due);
    
    if (paid == 0 && due == 0) return const SizedBox.shrink();

    return Panel(
      title: 'Paid vs Unpaid',
      child: SizedBox(
        height: 200,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              if (paid > 0)
                PieChartSectionData(
                  color: Colors.green,
                  value: paid,
                  title: '${(paid/(paid+due)*100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              if (due > 0)
                PieChartSectionData(
                  color: Colors.orange,
                  value: due,
                  title: '${(due/(paid+due)*100).toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopClientsList extends StatelessWidget {
  const _TopClientsList({required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> clientRevenue = {};
    for (final inv in invoices) {
      clientRevenue[inv.client.name] = (clientRevenue[inv.client.name] ?? 0) + inv.total;
    }

    final sorted = clientRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    if (top.isEmpty) return const SizedBox.shrink();

    return Panel(
      title: 'Top Clients',
      child: Column(
        children: top.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(money.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
