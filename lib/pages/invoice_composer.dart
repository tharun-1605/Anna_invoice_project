import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/payment.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../utils/formatters.dart';
import '../utils/pdf_generator.dart';
import '../widgets/common_widgets.dart';
import '../utils/download_helper.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvoiceComposer extends StatefulWidget {
  const InvoiceComposer({
    super.key,
    required this.store,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.studioItems,
    required this.onSaved,
    this.invoiceToEdit,
  });

  final InvoiceStore store;
  final List<Company> companies;
  final List<Client> clients;
  final List<StudioPackage> packages;
  final List<StudioItem> studioItems;
  final VoidCallback onSaved;
  final Invoice? invoiceToEdit;

  @override
  State<InvoiceComposer> createState() => _InvoiceComposerState();
}

class _InvoiceComposerState extends State<InvoiceComposer> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController(text: '188');
  final paid = TextEditingController(text: '0');
  final discountAmount = TextEditingController(text: '0');
  final notes = TextEditingController();
  DateTime invoiceDate = DateTime.now();
  DateTime dueDate = DateTime.now().add(const Duration(days: 7));
  Company? company;
  Client? client;
  List<_ItemDraft> items = [_ItemDraft()];
  String invoiceType = 'Tax Invoice';
  bool saving = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoiceToEdit;
    if (invoice == null) {
      _loadDraft();
      return;
    }

    number.text = invoice.number;
    paid.text = invoice.paid.toString();
    discountAmount.text = invoice.discountAmount.toString();
    notes.text = invoice.notes;
    invoiceDate = invoice.date;
    dueDate = invoice.dueDate;
    company = invoice.company;
    client = invoice.client;
    invoiceType = invoice.type;
    items = invoice.items
        .map(
          (item) => _ItemDraft(
            description: item.description,
            price: item.price.toString(),
            quantity: item.quantity.toString(),
          ),
        )
        .toList();
    if (items.isEmpty) items = [_ItemDraft()];
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftStr = prefs.getString('draft_invoice_state');
    if (draftStr == null) return;
    
    try {
      final draft = jsonDecode(draftStr);
      setState(() {
        number.text = draft['number'] ?? '';
        paid.text = draft['paid'] ?? '';
        discountAmount.text = draft['discountAmount'] ?? '';
        notes.text = draft['notes'] ?? '';
        
        if (draft['invoiceDate'] != null) invoiceDate = DateTime.parse(draft['invoiceDate']);
        if (draft['dueDate'] != null) dueDate = DateTime.parse(draft['dueDate']);
        if (draft['invoiceType'] != null) invoiceType = draft['invoiceType'];
        
        final cId = draft['companyId'];
        if (cId != null) {
          company = widget.companies.cast<Company?>().firstWhere((c) => c?.id == cId, orElse: () => null);
        }
        final clId = draft['clientId'];
        if (clId != null) {
          client = widget.clients.cast<Client?>().firstWhere((c) => c?.id == clId, orElse: () => null);
        }
        
        final draftItems = draft['items'] as List<dynamic>?;
        if (draftItems != null && draftItems.isNotEmpty) {
          for (final item in items) { item.dispose(); }
          items = draftItems.map((e) => _ItemDraft(
            description: e['description'] ?? '',
            quantity: e['quantity'] ?? '1',
            price: e['price'] ?? '0',
          )).toList();
        }
      });
    } catch (e) {
      // ignore
    }
  }

  void _onChanged() {
    setState(() {});
    if (widget.invoiceToEdit != null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'number': number.text,
      'paid': paid.text,
      'discountAmount': discountAmount.text,
      'notes': notes.text,
      'invoiceDate': invoiceDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'companyId': company?.id,
      'clientId': client?.id,
      'invoiceType': invoiceType,
      'items': items.map((e) => {
        'description': e.description.text,
        'quantity': e.quantity.text,
        'price': e.price.text,
      }).toList(),
    };
    await prefs.setString('draft_invoice_state', jsonEncode(draft));
  }

  @override
  void dispose() {
    number.dispose();
    paid.dispose();
    discountAmount.dispose();
    notes.dispose();
    for (final item in items) {
      item.dispose();
    }
    _saveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    company = _selectedCompany();
    client = _selectedClient();

    final invoice = _draftInvoice();
    final isEditing = widget.invoiceToEdit != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: isEditing ? 'Edit invoice' : 'Create invoice',
          subtitle: 'Build the invoice, save it to Firestore, then export PDF.',
          action: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_done_outlined),
            label: Text(isEditing ? 'Update invoice' : 'Save invoice'),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final form = Panel(title: 'Invoice form', child: _form());
            final preview = Panel(
              title: 'Preview',
              trailing: TextButton.icon(
                onPressed: invoice == null ? null : () => _print(invoice),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              child: invoice == null
                  ? const EmptyState('Add company, client, and item details')
                  : _InvoicePreview(invoice: invoice),
            );

            if (!wide) {
              return Column(
                children: [form, const SizedBox(height: 18), preview],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: form),
                const SizedBox(width: 18),
                Expanded(flex: 5, child: preview),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _form() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.companies.isEmpty || widget.clients.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: WarningBox('Add at least one company and one client before saving.'),
            ),
          DropdownButtonFormField<String>(
            initialValue: invoiceType,
            items: ['Tax Invoice', 'Quote', 'Proforma']
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              setState(() => invoiceType = value!);
              _onChanged();
            },
            decoration: const InputDecoration(labelText: 'Document Type'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Company>(
            initialValue: company,
            items: widget.companies
                .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                .toList(),
            onChanged: (value) {
              setState(() => company = value);
              _onChanged();
            },
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Client>(
            initialValue: client,
            items: widget.clients
                .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
                .toList(),
            onChanged: (value) {
              setState(() => client = value);
              _onChanged();
            },
            decoration: const InputDecoration(labelText: 'Client'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: number,
                  decoration: const InputDecoration(labelText: 'Invoice #'),
                  validator: requiredField,
                  onChanged: (_) => _onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: paid,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Paid amount'),
                  onChanged: (_) => _onChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: discountAmount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount (Amt)'),
                  onChanged: (_) => _onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Date',
                  value: invoiceDate,
                  onChanged: (value) {
                    invoiceDate = value;
                    _onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Due date',
                  value: dueDate,
                  onChanged: (value) {
                    dueDate = value;
                    _onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (widget.packages.isNotEmpty)
                PopupMenuButton<StudioPackage>(
                  tooltip: 'Add from packages',
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Add package',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onSelected: (pkg) {
                    final lines = [
                      if (pkg.description.isNotEmpty)
                        '${pkg.name} - ${pkg.description}'
                      else
                        pkg.name,
                      ...pkg.items,
                    ];
                    
                    setState(() {
                      items.add(
                        _ItemDraft(
                          description: lines.join('\n'),
                          price: pkg.price.toString(),
                          quantity: '1',
                        ),
                      );
                    });
                    _onChanged();
                  },
                  itemBuilder: (context) => widget.packages
                      .map((pkg) => PopupMenuItem(value: pkg, child: Text(pkg.name)))
                      .toList(),
                ),
              if (widget.studioItems.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showAddonsDialog(),
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text('Add add-ons'),
                ),
              TextButton.icon(
                onPressed: () {
                  setState(() => items.add(_ItemDraft()));
                  _onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.indexed.map((entry) {
            final index = entry.$1;
            final item = entry.$2;
            return _ItemEditor(
              key: ValueKey(item),
              item: item,
              canRemove: items.length > 1,
              onChanged: () => _onChanged(),
              onRemove: () {
                setState(() {
                  items.removeAt(index).dispose();
                });
                _onChanged();
              },
            );
          }),
          const SizedBox(height: 12),
          TextFormField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (_) => _onChanged(),
          ),
        ],
      ),
    );
  }

  Company? _selectedCompany() {
    final selected = company;
    if (widget.companies.isEmpty) return null;
    if (selected == null) return widget.companies.first;

    for (final item in widget.companies) {
      if (item.id == selected.id) return item;
    }
    return selected.id.isEmpty ? selected : widget.companies.first;
  }

  Client? _selectedClient() {
    final selected = client;
    if (widget.clients.isEmpty) return null;
    if (selected == null) return widget.clients.first;

    for (final item in widget.clients) {
      if (item.id == selected.id) return item;
    }
    return selected.id.isEmpty ? selected : widget.clients.first;
  }

  Invoice? _draftInvoice() {
    final selectedCompany = company;
    final selectedClient = client;
    if (selectedCompany == null || selectedClient == null) return null;

    final invoiceItems = items
        .map((item) => item.toInvoiceItem())
        .where((item) => item.description.trim().isNotEmpty)
        .toList();
    if (invoiceItems.isEmpty) return null;

    final currentPaid = double.tryParse(paid.text.trim()) ?? 0;
    List<Payment> draftPayments = widget.invoiceToEdit?.payments ?? [];
    final sumPayments = draftPayments.fold(0.0, (s, p) => s + p.amount);
    
    if (sumPayments != currentPaid) {
      if (draftPayments.isEmpty && currentPaid > 0) {
        draftPayments = [Payment(amount: currentPaid, method: 'Initial', date: DateTime.now())];
      } else if (currentPaid > 0) {
        final diff = currentPaid - sumPayments;
        draftPayments = List.from(draftPayments)..add(Payment(amount: diff, method: 'Adjustment', date: DateTime.now()));
      } else if (currentPaid == 0) {
        draftPayments = [];
      }
    }

    return Invoice(
      id: widget.invoiceToEdit?.id ?? '',
      number: number.text.trim().isEmpty ? 'Draft' : number.text.trim(),
      company: selectedCompany,
      client: selectedClient,
      date: invoiceDate,
      dueDate: dueDate,
      items: invoiceItems,
      paid: currentPaid,
      discountAmount: double.tryParse(discountAmount.text.trim()) ?? 0.0,
      notes: notes.text.trim(),
      createdAt: widget.invoiceToEdit?.createdAt ?? DateTime.now(),
      type: invoiceType,
      payments: draftPayments,
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final invoice = _draftInvoice();
    if (invoice == null) {
      _toast('Add company, client, and at least one invoice item.');
      return;
    }

    setState(() => saving = true);
    try {
      await widget.store.saveInvoice(invoice);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_invoice_state');
      _toast(widget.invoiceToEdit == null ? 'Invoice saved to Firestore.' : 'Invoice updated.');
      widget.onSaved();
    } on FirebaseException catch (error) {
      _toast(_firebaseSaveMessage(error));
    } catch (error) {
      _toast('Could not save invoice: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _print(Invoice invoice) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 50));

    Uint8List? bytes;
    try {
      bytes = await buildInvoicePdf(invoice);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _toast('Failed to generate PDF: $e');
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    await DownloadHelper.saveFileWithPermission(
      context: context,
      name: 'invoice-${invoice.number}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddonsDialog() async {
    final selectedItems = <StudioItem>{};
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Add-ons'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.studioItems.map((item) {
                    return CheckboxListTile(
                      title: Text(item.name),
                      subtitle: Text(money.format(item.price)),
                      value: selectedItems.contains(item),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedItems.add(item);
                          } else {
                            selectedItems.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedItems.isEmpty ? null : () => Navigator.pop(context, true),
                child: const Text('Add selected'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == true && selectedItems.isNotEmpty) {
      final names = selectedItems.map((e) => e.name).join(', ');
      final totalPrice = selectedItems.fold(0.0, (sum, e) => sum + e.price);
      
      setState(() {
        items.add(
          _ItemDraft(
            description: 'Add-ons\n$names',
            price: totalPrice.toString(),
            quantity: '1',
          ),
        );
      });
      _onChanged();
    }
  }
}

String _firebaseSaveMessage(FirebaseException error) {
  if (error.code == 'permission-denied') {
    return 'Could not save invoice: Firestore rules are blocking writes. Deploy firestore.rules.';
  }
  if (error.code == 'unavailable') {
    return 'Could not save invoice: Firestore is unavailable. Check your internet connection.';
  }
  if (error.code == 'failed-precondition') {
    return 'Could not save invoice: Firestore needs setup. ${error.message ?? error.code}';
  }
  return 'Could not save invoice: ${error.message ?? error.code}';
}

class _ItemDraft {
  _ItemDraft({
    String description = '',
    String quantity = '1',
    String price = '0',
  })  : description = TextEditingController(text: description),
        quantity = TextEditingController(text: quantity),
        price = TextEditingController(text: price);

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController price;

  InvoiceItem toInvoiceItem() => InvoiceItem(
        description: description.text.trim(),
        quantity: double.tryParse(quantity.text.trim()) ?? 0,
        price: double.tryParse(price.text.trim()) ?? 0,
      );

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({
    super.key,
    required this.item,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _ItemDraft item;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: item.description,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Description'),
                          validator: requiredField,
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove item',
                        onPressed: canRemove ? onRemove : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: item.quantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: item.price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Price'),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: item.description,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: requiredField,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item.quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: item.price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDate: value,
        );
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text('$label: ${dateFormatter.format(value)}'),
    );
  }
}

class _InvoicePreview extends StatelessWidget {
  const _InvoicePreview({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(logoPath, height: 72, width: 180, fit: BoxFit.contain),
              const Spacer(),
              Text(
                invoice.type.toUpperCase(),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AddressBlock(invoice.company.name, [
                      invoice.company.address,
                      invoice.company.phone,
                      invoice.company.email,
                    ]),
                    const SizedBox(height: 16),
                    _AddressBlock('BILL TO', [
                      invoice.client.name,
                      invoice.client.phone,
                      invoice.client.email,
                      invoice.client.address,
                    ]),
                    const SizedBox(height: 16),
                    _Facts(invoice, alignEnd: false),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AddressBlock(invoice.company.name, [
                      invoice.company.address,
                      invoice.company.phone,
                      invoice.company.email,
                    ]),
                  ),
                  Expanded(
                    child: _AddressBlock('BILL TO', [
                      invoice.client.name,
                      invoice.client.phone,
                      invoice.client.email,
                      invoice.client.address,
                    ]),
                  ),
                  Expanded(child: _Facts(invoice)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _PreviewTable(invoice: invoice),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                  _TotalLine('Subtotal', money.format(invoice.subtotal)),
                  if (invoice.discountAmount > 0)
                    _TotalLine('Discount', '-${money.format(invoice.discountAmount)}'),
                  _TotalLine('Total', money.format(invoice.total), strong: true),
                  _TotalLine('Paid', money.format(invoice.paid)),
                  const Divider(),
                  _TotalLine('Amount Due', money.format(invoice.due), strong: true),
                ],
              ),
            ),
          ),
          if (invoice.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(invoice.notes),
          ],
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock(this.title, this.lines);

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...lines
            .where((line) => line.trim().isNotEmpty)
            .map((line) => Text(line, style: const TextStyle(height: 1.45))),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts(this.invoice, {this.alignEnd = true});

  final Invoice invoice;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _FactLine('${invoice.type} #', invoice.number, alignEnd: alignEnd),
        _FactLine('Date', dateFormatter.format(invoice.date), alignEnd: alignEnd),
        _FactLine('Due date', dateFormatter.format(invoice.dueDate), alignEnd: alignEnd),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine(this.label, this.value, {this.alignEnd = true});

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          color: const Color(0xFF111827),
          child: const Row(
            children: [
              Expanded(flex: 5, child: _TableHeader('Item')),
              Expanded(child: _TableHeader('Qty')),
              Expanded(flex: 2, child: _TableHeader('Price')),
              Expanded(flex: 2, child: _TableHeader('Amount')),
            ],
          ),
        ),
        ...invoice.items.map(
          (item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.description.split('\n').first,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item.description.contains('\n'))
                        ...item.description.split('\n').skip(1).map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(line, style: const TextStyle(color: Colors.black87)),
                              ),
                            ),
                    ],
                  ),
                ),
                Expanded(child: Text(item.quantity.toStringAsFixed(0))),
                Expanded(flex: 2, child: Text(money.format(item.price))),
                Expanded(flex: 2, child: Text(money.format(item.amount))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              fontSize: strong ? 16 : 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                fontSize: strong ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
