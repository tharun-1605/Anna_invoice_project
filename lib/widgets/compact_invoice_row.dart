import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../utils/formatters.dart';

class CompactInvoiceRow extends StatelessWidget {
  const CompactInvoiceRow(this.invoice, {super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEFF6FF),
        foregroundColor: Color(0xFF2563EB),
        child: Icon(Icons.receipt_long_outlined),
      ),
      title: Text(
        '#${invoice.number} - ${invoice.client.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${dateFormatter.format(invoice.date)} - Due ${money.format(invoice.due)}',
      ),
      trailing: Text(
        money.format(invoice.total),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}
