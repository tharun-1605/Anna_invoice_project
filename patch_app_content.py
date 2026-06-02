import re

with open('lib/main.dart', 'r') as f:
    code = f.read()

replacement = """  const _AppContent({
    required this.view,
    required this.onViewChanged,
    required this.invoices,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.store,
    required this.loading,
    this.invoiceToEdit,
    required this.onEditInvoice,
  });

  final AppView view;
  final ValueChanged<AppView> onViewChanged;
  final List<Invoice> invoices;
  final List<Company> companies;
  final List<Client> clients;
  final List<StudioPackage> packages;
  final InvoiceStore store;
  final bool loading;
  final Invoice? invoiceToEdit;
  final ValueChanged<Invoice> onEditInvoice;"""

# Find the _AppContent block to replace
start_idx = code.find('  const _AppContent({')
end_idx = code.find('  @override\\n  Widget build(BuildContext context) {')

if start_idx != -1 and end_idx != -1:
    new_code = code[:start_idx] + replacement + "\\n\\n" + code[end_idx:]
    with open('lib/main.dart', 'w') as f:
        f.write(new_code)
    print("Replaced _AppContent constructor")
else:
    print("Could not find _AppContent constructor!")
    
# Now, find where _AppContent is instantiated and pass invoiceToEdit and onEditInvoice
find_str = """                            final content = _AppContent(
                              view: view,
                              onViewChanged: (next) =>
                                  setState(() => view = next),
                              invoices: invoicesSnapshot.data ?? [],
                              companies: companiesSnapshot.data ?? [],
                              clients: clientsSnapshot.data ?? [],
                              packages: packagesSnapshot.data ?? [],
                              store: store,
                              loading: invoicesSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  companiesSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  clientsSnapshot.connectionState ==
                                      ConnectionState.waiting,
                            );"""

replace_str = """                            final content = _AppContent(
                              view: view,
                              onViewChanged: (next) => setState(() {
                                view = next;
                                if (next != AppView.create) {
                                  _invoiceToEdit = null;
                                }
                              }),
                              invoices: invoicesSnapshot.data ?? [],
                              companies: companiesSnapshot.data ?? [],
                              clients: clientsSnapshot.data ?? [],
                              packages: packagesSnapshot.data ?? [],
                              store: store,
                              loading: invoicesSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  companiesSnapshot.connectionState ==
                                      ConnectionState.waiting ||
                                  clientsSnapshot.connectionState ==
                                      ConnectionState.waiting,
                              invoiceToEdit: _invoiceToEdit,
                              onEditInvoice: (inv) => setState(() {
                                _invoiceToEdit = inv;
                                view = AppView.create;
                              }),
                            );"""

if find_str in code:
    with open('lib/main.dart', 'w') as f:
        f.write(code.replace(find_str, replace_str))
    print("Replaced _AppContent instantiation")
else:
    print("Could not find _AppContent instantiation!")
