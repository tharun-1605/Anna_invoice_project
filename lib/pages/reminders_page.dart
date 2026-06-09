import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({
    super.key,
    required this.invoices,
    required this.store,
  });

  final List<Invoice> invoices;
  final InvoiceStore store;

  Future<void> _clearReminder(BuildContext context, Invoice invoice) async {
    final updated = Invoice(
      id: invoice.id,
      number: invoice.number,
      company: invoice.company,
      client: invoice.client,
      date: invoice.date,
      dueDate: invoice.dueDate,
      items: invoice.items,
      paid: invoice.paid,
      discountAmount: invoice.discountAmount,
      notes: invoice.notes,
      createdAt: invoice.createdAt,
      type: invoice.type,
      payments: invoice.payments,
      isReminderDismissed: true,
    );
    try {
      await store.saveInvoice(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder cleared')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear reminder: $e')));
      }
    }
  }

  Future<void> _sendReminder(BuildContext context, Invoice invoice) async {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final amountText = money.format(invoice.due);
    final msg = 'Hello ${invoice.client.name},\n\nThis is a friendly reminder that invoice ${invoice.number} has an outstanding balance of $amountText. Please arrange payment at your earliest convenience.\n\nThank you!';
    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdueInvoices = invoices.where((inv) {
      return inv.type == 'Tax Invoice' && 
             inv.due > 0 && 
             now.isAfter(inv.dueDate) && 
             !inv.isReminderDismissed;
    }).toList();

    overdueInvoices.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Reminders',
          subtitle: 'Overdue invoices that require follow-up',
        ),
        const SizedBox(height: 24),
        if (overdueInvoices.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text('All caught up! No active reminders.', style: TextStyle(fontSize: 16, color: Colors.black54)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: overdueInvoices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final inv = overdueInvoices[index];
              final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
              final dateFormatter = DateFormat('MMM dd, yyyy');
              final daysOverdue = now.difference(inv.dueDate).inDays;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.client.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Invoice ${inv.number}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Due: ${dateFormatter.format(inv.dueDate)} ($daysOverdue days overdue)',
                                style: TextStyle(color: Colors.red.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money.format(inv.due),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _clearReminder(context, inv),
                            icon: const Icon(Icons.done_all, size: 16),
                            label: const Text('Clear'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _sendReminder(context, inv),
                            icon: const Icon(Icons.send, size: 16),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green),
                            label: const Text('Remind'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
