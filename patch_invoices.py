import re

with open('lib/main.dart', 'r') as f:
    code = f.read()

# 1. Add invoiceToEdit to _InvoiceComposer
code = code.replace(
'''class _InvoiceComposer extends StatefulWidget {
  const _InvoiceComposer({
    super.key,
    required this.store,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.onSaved,
  });''',
'''class _InvoiceComposer extends StatefulWidget {
  const _InvoiceComposer({
    super.key,
    required this.store,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.onSaved,
    this.invoiceToEdit,
  });
  final Invoice? invoiceToEdit;'''
)

# 2. Update initState in _InvoiceComposerState
code = code.replace(
'''  @override
  void dispose() {''',
'''  @override
  void initState() {
    super.initState();
    if (widget.invoiceToEdit != null) {
      final i = widget.invoiceToEdit!;
      number.text = i.number;
      paid.text = i.paid.toString();
      notes.text = i.notes;
      invoiceDate = i.date;
      dueDate = i.dueDate;
      company = i.company;
      client = i.client;
      items = i.items.map((it) => _ItemDraft(
        desc: TextEditingController(text: it.description),
        price: TextEditingController(text: it.price.toString()),
        qty: TextEditingController(text: it.quantity.toString()),
      )).toList();
    }
  }

  @override
  void dispose() {'''
)

# 3. Update _draftInvoice to use invoiceToEdit.id
code = code.replace(
'''    return Invoice(
      id: '',
      number: number.text.trim().isEmpty ? 'Draft' : number.text.trim(),''',
'''    return Invoice(
      id: widget.invoiceToEdit?.id ?? '',
      number: number.text.trim().isEmpty ? 'Draft' : number.text.trim(),'''
)

# 4. Update title in _InvoiceComposer
code = code.replace(
'''        _PageHeader(
          title: 'Create invoice',
          subtitle: 'Build the invoice, save it to Firestore, then export PDF.',''',
'''        _PageHeader(
          title: widget.invoiceToEdit == null ? 'Create invoice' : 'Edit invoice',
          subtitle: 'Build the invoice, save it to Firestore, then export PDF.','''
)

with open('lib/main.dart', 'w') as f:
    f.write(code)
