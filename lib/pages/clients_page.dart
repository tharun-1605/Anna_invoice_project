import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/client.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({
    super.key,
    required this.store,
    required this.clients,
    required this.onViewLedger,
  });

  final InvoiceStore store;
  final List<Client> clients;
  final ValueChanged<Client> onViewLedger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Clients',
          subtitle: 'Keep client billing details ready for fast invoice entry.',
          action: FilledButton.icon(
            onPressed: () => showClientDialog(context, store),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add client'),
          ),
        ),
        const SizedBox(height: 18),
        if (clients.isEmpty)
          const Panel(title: 'Clients', child: EmptyState('Add a client'))
        else
          ResponsiveGrid(
            children: clients
                .map(
                  (client) => InfoCard(
                    title: client.name,
                    lines: [
                      client.phone,
                      client.email,
                      client.address,
                      if (client.eventDate.isNotEmpty) 'Event: ${client.eventDate}',
                      if (client.reference.isNotEmpty) 'Ref: ${client.reference}',
                      'Priority: ${client.priority}',
                    ],
                    icon: Icons.person_outline,
                    extraAction: client.fromLead ? const Padding(padding: EdgeInsets.only(top: 8), child: Chip(label: Text('From Lead', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact)) : null,
                    onView: () => onViewLedger(client),
                    onEdit: () => showClientDialog(context, store, client),
                    onDelete: () async {
                      final confirm = await confirmDelete(context, client.name);
                      if (confirm == true) {
                        await store.deleteClient(client.id);
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
