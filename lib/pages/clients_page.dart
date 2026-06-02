import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/client.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key, required this.store, required this.clients});

  final InvoiceStore store;
  final List<Client> clients;

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
                    lines: [client.phone, client.email, client.address],
                    icon: Icons.person_outline,
                    onEdit: () => showClientDialog(context, store, client),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
