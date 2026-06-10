import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/lead.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({
    super.key,
    required this.store,
    required this.leads,
    this.onCreateQuote,
  });

  final InvoiceStore store;
  final List<Lead> leads;
  final ValueChanged<Lead>? onCreateQuote;

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  bool _showRejected = false;

  @override
  Widget build(BuildContext context) {
    final filteredLeads = widget.leads.where((l) => _showRejected || !l.isRejected).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Leads',
          subtitle: 'Manage potential clients and convert them to active clients.',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterChip(
                label: const Text('Show Rejected'),
                selected: _showRejected,
                onSelected: (val) => setState(() => _showRejected = val),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => showLeadDialog(context, widget.store),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add lead'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (filteredLeads.isEmpty)
          const Panel(title: 'Leads', child: EmptyState('No leads found'))
        else
          ResponsiveGrid(
            children: filteredLeads
                .map(
                  (lead) => InfoCard(
                    title: lead.name,
                    lines: [
                      lead.phone,
                      lead.email,
                      lead.address,
                      if (lead.eventDate.isNotEmpty) 'Event: ${lead.eventDate}',
                      if (lead.reference.isNotEmpty) 'Ref: ${lead.reference}',
                      'Priority: ${lead.priority}',
                    ],
                    icon: Icons.person_add_alt_1_outlined,
                    onView: null,
                    onEdit: () => showLeadDialog(context, widget.store, lead),
                    onDelete: () async {
                      final confirm = await confirmDelete(context, lead.name);
                      if (confirm == true) {
                        await widget.store.deleteLead(lead.id);
                      }
                    },
                    extraAction: lead.isRejected
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.block, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Rejected: ${lead.rejectReason}', style: const TextStyle(color: Colors.red, fontSize: 12))),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
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
                                            await widget.store.convertLeadToClient(lead);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('${lead.name} converted to client')),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.check_circle_outline, size: 18),
                                        label: const Text('Convert'),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(36),
                                          backgroundColor: Colors.green.shade600,
                                        ),
                                      ),
                                    ),
                                    if (widget.onCreateQuote != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => widget.onCreateQuote!(lead),
                                          icon: const Icon(Icons.request_quote_outlined, size: 18),
                                          label: const Text('Quote'),
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size.fromHeight(36),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final reasonCtrl = TextEditingController();
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Reject Lead?'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Are you sure you want to reject ${lead.name}?'),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: reasonCtrl,
                                              decoration: const InputDecoration(labelText: 'Reason for rejection'),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                            child: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await widget.store.rejectLead(lead.id, reasonCtrl.text.trim());
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${lead.name} rejected')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  label: const Text('Reject Lead', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(36),
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ],
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
