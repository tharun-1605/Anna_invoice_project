import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class DialogField {
  const DialogField(this.label, this.controller, {this.lines = 1});

  final String label;
  final TextEditingController controller;
  final int lines;
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
      DialogField('Phone', phone),
      DialogField('Email', email),
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
      DialogField('Phone', phone),
      DialogField('Email', email),
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
  final nameCtrl = TextEditingController(text: package?.name);
  final descCtrl = TextEditingController(text: package?.description);
  final priceCtrl = TextEditingController(text: package?.price.toString() ?? '');

  await showEntityDialog(
    context: context,
    title: package == null ? 'New Package' : 'Edit Package',
    fields: [
      DialogField('Package name', nameCtrl),
      DialogField('Description', descCtrl, lines: 3),
      DialogField('Price', priceCtrl),
    ],
    onSave: () => store.savePackage(
      StudioPackage(
        id: package?.id ?? '',
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        price: double.tryParse(priceCtrl.text) ?? 0,
      ),
    ),
  );
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
