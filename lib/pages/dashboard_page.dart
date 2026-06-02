import 'package:flutter/material.dart';

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
    final paid = invoices.fold<double>(
      0,
      (runningTotal, invoice) => runningTotal + invoice.paid,
    );
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Panel(
                title: 'Recent invoices',
                child: invoices.isEmpty
                    ? const EmptyState('No invoices yet')
                    : Column(
                        children: invoices.take(6).map(CompactInvoiceRow.new).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: Panel(
                title: 'Quick status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusLine('Companies', companies.length.toString()),
                    StatusLine('Paid collected', money.format(paid)),
                    const StatusLine('Firestore', 'Connected'),
                    const StatusLine('Plan', 'Free resources only'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
