import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class DialogField {
  const DialogField(this.label, this.controller, {this.lines = 1, this.keyboardType});

  final String label;
  final TextEditingController controller;
  final int lines;
  final TextInputType? keyboardType;
}

Future<void> showCompanyDialog(
  BuildContext context,
  InvoiceStore store, [
  Company? company,
]) async {
  final name = TextEditingController(text: company?.name ?? 'ZA Pictures');
  final address = TextEditingController(text: company?.address ?? '');
  final phone = TextEditingController(text: company?.phone ?? '');
  final email = TextEditingController(text: company?.email ?? '');
  await showEntityDialog(
    context: context,
    title: company == null ? 'Add company' : 'Edit company',
    fields: [
      DialogField('Company name', name),
      DialogField('Address', address, lines: 3),
      DialogField('Phone', phone, keyboardType: TextInputType.phone),
      DialogField('Email', email, keyboardType: TextInputType.emailAddress),
    ],
    onSave: () => store.saveCompany(
      Company(
        id: company?.id ?? '',
        name: name.text.trim(),
        address: address.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
      ),
    ),
  );
}

Future<void> showClientDialog(
  BuildContext context,
  InvoiceStore store, [
  Client? client,
]) async {
  final name = TextEditingController(text: client?.name ?? '');
  final phone = TextEditingController(text: client?.phone ?? '');
  final email = TextEditingController(text: client?.email ?? '');
  final address = TextEditingController(text: client?.address ?? '');
  await showEntityDialog(
    context: context,
    title: client == null ? 'Add client' : 'Edit client',
    fields: [
      DialogField('Client name', name),
      DialogField('Phone (e.g. +91...)', phone, keyboardType: TextInputType.phone),
      DialogField('Email', email, keyboardType: TextInputType.emailAddress),
      DialogField('Address', address, lines: 3),
    ],
    onSave: () => store.saveClient(
      Client(
        id: client?.id ?? '',
        name: name.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        address: address.text.trim(),
      ),
    ),
  );
}

Future<void> showPackageDialog(
  BuildContext context,
  InvoiceStore store, [
  StudioPackage? package,
]) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _PackageDialog(
      store: store,
      package: package,
    ),
  );
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({required this.store, this.package});

  final InvoiceStore store;
  final StudioPackage? package;

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  final List<TextEditingController> itemCtrls = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.package?.name);
    descCtrl = TextEditingController(text: widget.package?.description);
    priceCtrl = TextEditingController(text: widget.package?.price.toString() ?? '');
    
    if (widget.package != null && widget.package!.items.isNotEmpty) {
      for (final item in widget.package!.items) {
        itemCtrls.add(TextEditingController(text: item));
      }
    } else {
      itemCtrls.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    for (final ctrl in itemCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.package == null ? 'New Package' : 'Edit Package'),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Package name'),
                  validator: requiredField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Package Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          itemCtrls.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...itemCtrls.indexed.map((entry) {
                  final index = entry.$1;
                  final ctrl = entry.$2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ctrl,
                            decoration: InputDecoration(labelText: 'Item ${index + 1}'),
                            validator: requiredField,
                          ),
                        ),
                        if (itemCtrls.length > 1)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                itemCtrls.removeAt(index).dispose();
                              });
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    await widget.store.savePackage(
                      StudioPackage(
                        id: widget.package?.id ?? '',
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text) ?? 0,
                        items: itemCtrls
                            .map((c) => c.text.trim())
                            .where((text) => text.isNotEmpty)
                            .toList(),
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Save failed: $error')),
                      );
                    }
                    setState(() => saving = false);
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> showEntityDialog({
  required BuildContext context,
  required String title,
  required List<DialogField> fields,
  required Future<void> Function() onSave,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _EntityDialog(
      title: title,
      fields: fields,
      onSave: onSave,
    ),
  );
}

class _EntityDialog extends StatefulWidget {
  const _EntityDialog({
    required this.title,
    required this.fields,
    required this.onSave,
  });

  final String title;
  final List<DialogField> fields;
  final Future<void> Function() onSave;

  @override
  State<_EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends State<_EntityDialog> {
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  @override
  void dispose() {
    for (final field in widget.fields) {
      field.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: field.controller,
                        minLines: field.lines,
                        maxLines: field.lines,
                        keyboardType: field.keyboardType,
                        decoration: InputDecoration(labelText: field.label),
                        validator: field.label.contains('name') ||
                                field.label.contains('Company')
                            ? requiredField
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!formKey.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    await widget.onSave();
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Save failed: $error')),
                      );
                    }
                    setState(() => saving = false);
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
