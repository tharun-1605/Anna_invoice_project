import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/lead.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class LeadsPage extends StatelessWidget {
  const LeadsPage({
    super.key,
    required this.store,
    required this.leads,
  });

  final InvoiceStore store;
  final List<Lead> leads;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Leads',
          subtitle: 'Manage potential clients and convert them to active clients.',
          action: FilledButton.icon(
            onPressed: () => showLeadDialog(context, store),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add lead'),
          ),
        ),
        const SizedBox(height: 18),
        if (leads.isEmpty)
          const Panel(title: 'Leads', child: EmptyState('Add a lead'))
        else
          ResponsiveGrid(
            children: leads
                .map(
                  (lead) => InfoCard(
                    title: lead.name,
                    lines: [lead.phone, lead.email, lead.address],
                    icon: Icons.person_add_alt_1_outlined,
                    onView: null,
                    onEdit: () => showLeadDialog(context, store, lead),
                    onDelete: () async {
                      final confirm = await confirmDelete(context, lead.name);
                      if (confirm == true) {
                        await store.deleteLead(lead.id);
                      }
                    },
                    extraAction: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Convert to Client?'),
                              content: Text('Are you sure you want to convert ${lead.name} to a client?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Convert'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await store.convertLeadToClient(lead);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${lead.name} converted to client')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Convert to Client'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          backgroundColor: Colors.green.shade600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
