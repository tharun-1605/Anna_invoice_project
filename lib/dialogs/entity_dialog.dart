import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/lead.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../widgets/common_widgets.dart';

class DialogField {
  const DialogField(this.label, this.controller, {this.lines = 1, this.keyboardType, this.choices});

  final String label;
  final TextEditingController controller;
  final int lines;
  final TextInputType? keyboardType;
  final List<String>? choices;
}

Future<void> showCompanyDialog(
  BuildContext context,
  InvoiceStore store, [
  Company? company,
]) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CompanyDialog(
      store: store,
      company: company,
    ),
  );
}

class _CompanyDialog extends StatefulWidget {
  const _CompanyDialog({required this.store, this.company});

  final InvoiceStore store;
  final Company? company;

  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  bool saving = false;
  String signatureBase64 = '';

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.company?.name ?? 'ZA Pictures');
    addressCtrl = TextEditingController(text: widget.company?.address ?? '');
    phoneCtrl = TextEditingController(text: widget.company?.phone ?? '');
    emailCtrl = TextEditingController(text: widget.company?.email ?? '');
    signatureBase64 = widget.company?.signatureBase64 ?? '';
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addressCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSignature() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 200,
      imageQuality: 70,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        signatureBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.company == null ? 'Add company' : 'Edit company'),
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
                  decoration: const InputDecoration(labelText: 'Company name'),
                  validator: requiredField,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  minLines: 3,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 24),
                Text('Digital Signature', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (signatureBase64.isNotEmpty)
                  Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(child: Image.memory(base64Decode(signatureBase64))),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => signatureBase64 = ''),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickSignature,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Signature (PNG/JPG)'),
                  ),
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
                    await widget.store.saveCompany(
                      Company(
                        id: widget.company?.id ?? '',
                        name: nameCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        signatureBase64: signatureBase64,
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

Future<void> showClientDialog(
  BuildContext context,
  InvoiceStore store, [
  Client? client,
]) async {
  final name = TextEditingController(text: client?.name ?? '');
  final phone = TextEditingController(text: client?.phone ?? '');
  final email = TextEditingController(text: client?.email ?? '');
  final address = TextEditingController(text: client?.address ?? '');
  final eventDate = TextEditingController(text: client?.eventDate ?? '');
  final priority = TextEditingController(text: client?.priority.isEmpty ?? true ? 'Medium' : client!.priority);
  final reference = TextEditingController(text: client?.reference ?? '');
  await showEntityDialog(
    context: context,
    title: client == null ? 'Add client' : 'Edit client',
    fields: [
      DialogField('Client name', name),
      DialogField('Phone (e.g. +91...)', phone, keyboardType: TextInputType.phone),
      DialogField('Email', email, keyboardType: TextInputType.emailAddress),
      DialogField('Event Date (e.g., YYYY-MM-DD)', eventDate, keyboardType: TextInputType.datetime),
      DialogField('Priority', priority, choices: ['High', 'Medium', 'Low']),
      DialogField('Reference (e.g. Social Media, Friend)', reference),
      DialogField('Address', address, lines: 3),
    ],
    onSave: () => store.saveClient(
      Client(
        id: client?.id ?? '',
        name: name.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        address: address.text.trim(),
        eventDate: eventDate.text.trim(),
        priority: priority.text.trim(),
        reference: reference.text.trim(),
      ),
    ),
  );
}

Future<void> showLeadDialog(
  BuildContext context,
  InvoiceStore store, [
  Lead? lead,
]) async {
  final name = TextEditingController(text: lead?.name ?? '');
  final phone = TextEditingController(text: lead?.phone ?? '');
  final email = TextEditingController(text: lead?.email ?? '');
  final address = TextEditingController(text: lead?.address ?? '');
  final eventDate = TextEditingController(text: lead?.eventDate ?? '');
  final priority = TextEditingController(text: lead?.priority.isEmpty ?? true ? 'Medium' : lead!.priority);
  final reference = TextEditingController(text: lead?.reference ?? '');
  await showEntityDialog(
    context: context,
    title: lead == null ? 'Add lead' : 'Edit lead',
    fields: [
      DialogField('Lead name', name),
      DialogField('Phone (e.g. +91...)', phone, keyboardType: TextInputType.phone),
      DialogField('Email', email, keyboardType: TextInputType.emailAddress),
      DialogField('Event Date (e.g., YYYY-MM-DD)', eventDate, keyboardType: TextInputType.datetime),
      DialogField('Priority', priority, choices: ['High', 'Medium', 'Low']),
      DialogField('Reference (e.g. Social Media, Friend)', reference),
      DialogField('Address', address, lines: 3),
    ],
    onSave: () => store.saveLead(
      Lead(
        id: lead?.id ?? '',
        name: name.text.trim(),
        phone: phone.text.trim(),
        email: email.text.trim(),
        address: address.text.trim(),
        eventDate: eventDate.text.trim(),
        priority: priority.text.trim(),
        reference: reference.text.trim(),
      ),
    ),
  );
}

Future<void> showStudioItemDialog(
  BuildContext context,
  InvoiceStore store, [
  StudioItem? item,
]) async {
  final name = TextEditingController(text: item?.name ?? '');
  final price = TextEditingController(text: item?.price.toString() ?? '');
  await showEntityDialog(
    context: context,
    title: item == null ? 'Add standalone item' : 'Edit standalone item',
    fields: [
      DialogField('Item name', name),
      DialogField('Price', price, keyboardType: TextInputType.number),
    ],
    onSave: () => store.saveStudioItem(
      StudioItem(
        id: item?.id ?? '',
        name: name.text.trim(),
        price: double.tryParse(price.text.trim()) ?? 0,
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
                      child: field.choices != null
                          ? DropdownButtonFormField<String>(
                              value: field.controller.text.isEmpty ? field.choices!.first : field.controller.text,
                              decoration: InputDecoration(labelText: field.label),
                              items: field.choices!.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  field.controller.text = newValue;
                                }
                              },
                            )
                          : TextFormField(
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
