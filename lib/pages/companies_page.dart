import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/company.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class CompaniesPage extends StatelessWidget {
  const CompaniesPage({super.key, required this.store, required this.companies});

  final InvoiceStore store;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Companies',
          subtitle: 'Save your billing company details for invoices.',
          action: FilledButton.icon(
            onPressed: () => showCompanyDialog(context, store),
            icon: const Icon(Icons.add_business),
            label: const Text('Add company'),
          ),
        ),
        const SizedBox(height: 18),
        if (companies.isEmpty)
          const Panel(title: 'Companies', child: EmptyState('Add a company'))
        else
          ResponsiveGrid(
            children: companies
                .map(
                  (company) => InfoCard(
                    title: company.name,
                    lines: [company.address, company.phone, company.email],
                    icon: Icons.business_outlined,
                    onEdit: () => showCompanyDialog(context, store, company),
                    onDelete: () async {
                      final confirm = await confirmDelete(context, company.name);
                      if (confirm == true) {
                        await store.deleteCompany(company.id);
                      }
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
