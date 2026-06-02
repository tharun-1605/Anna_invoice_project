import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import 'firebase_options.dart';
import 'models/company.dart';
import 'models/client.dart';
import 'models/invoice_item.dart';
import 'models/invoice.dart';
import 'models/studio_package.dart';
import 'services/invoice_store.dart';
import 'utils/formatters.dart';
import 'utils/pdf_generator.dart';

const _logoPath = logoPath;
final _money = money;
final _date = dateFormatter;
Future<Uint8List> _buildInvoicePdf(Invoice invoice) => buildInvoicePdf(invoice);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ZaInvoiceApp());
}

class ZaInvoiceApp extends StatelessWidget {
  const ZaInvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZA Invoice Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF111827),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        fontFamily: 'Roboto',
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: const InvoiceShell(),
    );
  }
}


enum AppView { dashboard, companies, clients, invoices, packages, create }

class InvoiceShell extends StatefulWidget {
  const InvoiceShell({super.key});

  @override
  State<InvoiceShell> createState() => _InvoiceShellState();
}

class _InvoiceShellState extends State<InvoiceShell> {
  late final InvoiceStore store;
  AppView view = AppView.dashboard;

  @override
  void initState() {
    super.initState();
    store = InvoiceStore(FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Company>>(
      stream: store.companies(),
      builder: (context, companiesSnapshot) {
        return StreamBuilder<List<Client>>(
          stream: store.clients(),
          builder: (context, clientsSnapshot) {
            return StreamBuilder<List<Invoice>>(
              stream: store.invoices(),
              builder: (context, invoicesSnapshot) {
                return StreamBuilder<List<StudioPackage>>(
                  stream: store.packages(),
                  builder: (context, packagesSnapshot) {
                    final companies = companiesSnapshot.data ?? [];
                    final clients = clientsSnapshot.data ?? [];
                    final invoices = invoicesSnapshot.data ?? [];
                    final packages = packagesSnapshot.data ?? [];
                    final loading =
                        companiesSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        clientsSnapshot.connectionState ==
                            ConnectionState.waiting ||
                        invoicesSnapshot.connectionState == ConnectionState.waiting ||
                        packagesSnapshot.connectionState == ConnectionState.waiting;

                    return Scaffold(
                      body: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;
                            final content = _AppContent(
                              view: view,
                              store: store,
                              companies: companies,
                              clients: clients,
                              invoices: invoices,
                              packages: packages,
                              loading: loading,
                              onViewChanged: (next) => setState(() => view = next),
                            );

                        if (!wide) {
                          return Column(
                            children: [
                              _MobileBar(
                                view: view,
                                onViewChanged: (next) =>
                                    setState(() => view = next),
                              ),
                              Expanded(child: content),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            _SideNav(
                              view: view,
                              onViewChanged: (next) =>
                                  setState(() => view = next),
                            ),
                            Expanded(child: content),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
      },
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.view, required this.onViewChanged});

  final AppView view;
  final ValueChanged<AppView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(_logoPath, height: 72, fit: BoxFit.contain),
          const SizedBox(height: 24),
          Text(
            'Invoice Studio',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          _NavButton(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            active: view == AppView.dashboard,
            onTap: () => onViewChanged(AppView.dashboard),
          ),
          _NavButton(
            icon: Icons.business_outlined,
            label: 'Companies',
            active: view == AppView.companies,
            onTap: () => onViewChanged(AppView.companies),
          ),
          _NavButton(
            icon: Icons.people_alt_outlined,
            label: 'Clients',
            active: view == AppView.clients,
            onTap: () => onViewChanged(AppView.clients),
          ),
          _NavButton(
            icon: Icons.receipt_long_outlined,
            label: 'Invoices',
            active: view == AppView.invoices,
            onTap: () => onViewChanged(AppView.invoices),
          ),
          _NavButton(
            icon: Icons.inventory_2_outlined,
            label: 'Packages',
            active: view == AppView.packages,
            onTap: () => onViewChanged(AppView.packages),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => onViewChanged(AppView.create),
            icon: const Icon(Icons.add),
            label: const Text('New invoice'),
          ),
        ],
      ),
    );
  }
}

class _MobileBar extends StatelessWidget {
  const _MobileBar({required this.view, required this.onViewChanged});

  final AppView view;
  final ValueChanged<AppView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Image.asset(
                  _logoPath,
                  height: 44,
                  width: 86,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => onViewChanged(AppView.create),
                  icon: const Icon(Icons.add),
                  label: const Text('Invoice'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                _ChipNav('Dashboard', AppView.dashboard, view, onViewChanged),
                _ChipNav('Companies', AppView.companies, view, onViewChanged),
                _ChipNav('Clients', AppView.clients, view, onViewChanged),
                _ChipNav('Invoices', AppView.invoices, view, onViewChanged),
                _ChipNav('Packages', AppView.packages, view, onViewChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipNav extends StatelessWidget {
  const _ChipNav(this.label, this.target, this.view, this.onViewChanged);

  final String label;
  final AppView target;
  final AppView view;
  final ValueChanged<AppView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: view == target,
        onSelected: (_) => onViewChanged(target),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF111827) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? Colors.white : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF111827),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent({
    required this.view,
    required this.store,
    required this.companies,
    required this.clients,
    required this.invoices,
    required this.packages,
    required this.loading,
    required this.onViewChanged,
  });

  final AppView view;
  final InvoiceStore store;
  final List<Company> companies;
  final List<Client> clients;
  final List<Invoice> invoices;
  final List<StudioPackage> packages;
  final bool loading;
  final ValueChanged<AppView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (view) {
      case AppView.dashboard:
        page = _Dashboard(
          invoices: invoices,
          companies: companies,
          clients: clients,
          packages: packages,
          loading: loading,
          onCreate: () => onViewChanged(AppView.create),
        );
      case AppView.companies:
        page = _CompaniesPage(store: store, companies: companies);
      case AppView.clients:
        page = _ClientsPage(store: store, clients: clients);
      case AppView.invoices:
        page = _InvoicesPage(invoices: invoices);
      case AppView.packages:
        page = _PackagesPage(store: store, packages: packages);
      case AppView.create:
        page = _InvoiceComposer(
          store: store,
          companies: companies,
          clients: clients,
          packages: packages,
          onSaved: () => onViewChanged(AppView.invoices),
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: SingleChildScrollView(
        key: ValueKey(view),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: page,
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.invoices,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.loading,
    required this.onCreate,
  });

  final List<Invoice> invoices;
  final List<Company> companies;
  final List<Client> clients;
  final List<StudioPackage> packages;
  final bool loading;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final paid = invoices.fold<double>(
      0,
      (runningTotal, invoice) => runningTotal + invoice.paid,
    );
    final total = invoices.fold<double>(
      0,
      (runningTotal, invoice) => runningTotal + invoice.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Dashboard',
          subtitle: 'Create, save, and export ZA Pictures invoices.',
          action: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create invoice'),
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          children: [
            _MetricCard(
              'Invoices',
              invoices.length.toString(),
              Icons.receipt_long,
            ),
            _MetricCard('Clients', clients.length.toString(), Icons.people),
            _MetricCard('Packages', packages.length.toString(), Icons.inventory_2),
            _MetricCard('Revenue', _money.format(total), Icons.trending_up),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Panel(
                title: 'Recent invoices',
                child: invoices.isEmpty
                    ? const _EmptyState('No invoices yet')
                    : Column(
                        children: invoices
                            .take(6)
                            .map(_InvoiceRow.new)
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: _Panel(
                title: 'Quick status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusLine('Companies', companies.length.toString()),
                    _StatusLine('Paid collected', _money.format(paid)),
                    _StatusLine('Firestore', 'Connected'),
                    _StatusLine('Plan', 'Free resources only'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompaniesPage extends StatelessWidget {
  const _CompaniesPage({required this.store, required this.companies});

  final InvoiceStore store;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Companies',
          subtitle: 'Save your billing company details for invoices.',
          action: FilledButton.icon(
            onPressed: () => _showCompanyDialog(context, store),
            icon: const Icon(Icons.add_business),
            label: const Text('Add company'),
          ),
        ),
        const SizedBox(height: 18),
        if (companies.isEmpty)
          const _Panel(title: 'Companies', child: _EmptyState('Add a company'))
        else
          _ResponsiveGrid(
            children: companies
                .map(
                  (company) => _InfoCard(
                    title: company.name,
                    lines: [company.address, company.phone, company.email],
                    icon: Icons.business_outlined,
                    onEdit: () => _showCompanyDialog(context, store, company),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _ClientsPage extends StatelessWidget {
  const _ClientsPage({required this.store, required this.clients});

  final InvoiceStore store;
  final List<Client> clients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Clients',
          subtitle: 'Keep client billing details ready for fast invoice entry.',
          action: FilledButton.icon(
            onPressed: () => _showClientDialog(context, store),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Add client'),
          ),
        ),
        const SizedBox(height: 18),
        if (clients.isEmpty)
          const _Panel(title: 'Clients', child: _EmptyState('Add a client'))
        else
          _ResponsiveGrid(
            children: clients
                .map(
                  (client) => _InfoCard(
                    title: client.name,
                    lines: [client.phone, client.email, client.address],
                    icon: Icons.person_outline,
                    onEdit: () => _showClientDialog(context, store, client),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PackagesPage extends StatelessWidget {
  const _PackagesPage({required this.store, required this.packages});

  final InvoiceStore store;
  final List<StudioPackage> packages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Packages & Items',
          subtitle: 'Manage your predefined photo packages and items.',
          action: FilledButton.icon(
            onPressed: () => _showPackageDialog(context, store),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add package'),
          ),
        ),
        const SizedBox(height: 18),
        if (packages.isEmpty)
          const _Panel(title: 'Packages', child: _EmptyState('Add a package'))
        else
          _ResponsiveGrid(
            children: packages
                .map(
                  (pkg) => _InfoCard(
                    title: pkg.name,
                    lines: [pkg.description, 'Price: ${_money.format(pkg.price)}'],
                    icon: Icons.inventory_2_outlined,
                    onEdit: () => _showPackageDialog(context, store, pkg),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

Future<void> _showPackageDialog(
  BuildContext context,
  InvoiceStore store, [
  StudioPackage? package,
]) async {
  final nameCtrl = TextEditingController(text: package?.name);
  final descCtrl = TextEditingController(text: package?.description);
  final priceCtrl = TextEditingController(text: package?.price.toString() ?? '');

  await _showEntityDialog(
    context: context,
    title: package == null ? 'New Package' : 'Edit Package',
    fields: [
      _DialogField('Package name', nameCtrl),
      _DialogField('Description', descCtrl, lines: 3),
      _DialogField('Price', priceCtrl),
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

class _InvoicesPage extends StatelessWidget {
  const _InvoicesPage({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeader(
          title: 'Invoices',
          subtitle: 'Saved invoices from Firestore.',
        ),
        const SizedBox(height: 18),
        _Panel(
          title: 'Saved invoices',
          child: invoices.isEmpty
              ? const _EmptyState('No saved invoices')
              : Column(children: invoices.map(_InvoiceRow.new).toList()),
        ),
      ],
    );
  }
}

class _InvoiceComposer extends StatefulWidget {
  const _InvoiceComposer({
    super.key,
    required this.store,
    required this.companies,
    required this.clients,
    required this.packages,
    required this.onSaved,
  });

  final InvoiceStore store;
  final List<Company> companies;
  final List<Client> clients;
  final List<StudioPackage> packages;
  final VoidCallback onSaved;

  @override
  State<_InvoiceComposer> createState() => _InvoiceComposerState();
}

class _InvoiceComposerState extends State<_InvoiceComposer> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController(text: '188');
  final paid = TextEditingController(text: '0');
  final notes = TextEditingController();
  DateTime invoiceDate = DateTime.now();
  DateTime dueDate = DateTime.now().add(const Duration(days: 7));
  Company? company;
  Client? client;
  List<_ItemDraft> items = [_ItemDraft()];
  bool saving = false;

  @override
  void dispose() {
    number.dispose();
    paid.dispose();
    notes.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    company = _selectedCompany();
    client = _selectedClient();

    final invoice = _draftInvoice();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Create invoice',
          subtitle: 'Build the invoice, save it to Firestore, then export PDF.',
          action: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_done_outlined),
            label: const Text('Save invoice'),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final form = _Panel(title: 'Invoice form', child: _form());
            final preview = _Panel(
              title: 'Preview',
              trailing: TextButton.icon(
                onPressed: invoice == null ? null : () => _print(invoice),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
              child: invoice == null
                  ? const _EmptyState('Add company, client, and item details')
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
              child: _WarningBox(
                'Add at least one company and one client before saving.',
              ),
            ),
          DropdownButtonFormField<Company>(
            initialValue: company,
            items: widget.companies
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => company = value),
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Client>(
            initialValue: client,
            items: widget.clients
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => client = value),
            decoration: const InputDecoration(labelText: 'Client'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: number,
                  decoration: const InputDecoration(labelText: 'Invoice #'),
                  validator: _required,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: paid,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Paid amount'),
                  onChanged: (_) => setState(() {}),
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
                  onChanged: (value) => setState(() => invoiceDate = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Due date',
                  value: dueDate,
                  onChanged: (value) => setState(() => dueDate = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Items',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (widget.packages.isNotEmpty)
                PopupMenuButton<StudioPackage>(
                  tooltip: 'Add from packages',
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text('Add package',
                            style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  onSelected: (pkg) {
                    setState(() {
                      final draft = _ItemDraft();
                      draft.description.text = pkg.description.isNotEmpty
                          ? '${pkg.name} - ${pkg.description}'
                          : pkg.name;
                      draft.price.text = pkg.price.toString();
                      draft.quantity.text = '1';
                      items.add(draft);
                    });
                  },
                  itemBuilder: (context) => widget.packages
                      .map((pkg) => PopupMenuItem(
                            value: pkg,
                            child: Text(pkg.name),
                          ))
                      .toList(),
                ),
              TextButton.icon(
                onPressed: () => setState(() => items.add(_ItemDraft())),
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
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                items.removeAt(index).dispose();
              }),
            );
          }),
          const SizedBox(height: 12),
          TextFormField(
            controller: notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notes'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Company? _selectedCompany() {
    final selected = company;
    if (widget.companies.isEmpty) return null;
    if (selected == null) return widget.companies.first;

    return widget.companies
        .where((item) => item.id == selected.id)
        .firstOrNull ?? widget.companies.first;
  }

  Client? _selectedClient() {
    final selected = client;
    if (widget.clients.isEmpty) return null;
    if (selected == null) return widget.clients.first;

    return widget.clients
        .where((item) => item.id == selected.id)
        .firstOrNull ?? widget.clients.first;
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

    return Invoice(
      id: '',
      number: number.text.trim().isEmpty ? 'Draft' : number.text.trim(),
      company: selectedCompany,
      client: selectedClient,
      date: invoiceDate,
      dueDate: dueDate,
      items: invoiceItems,
      paid: double.tryParse(paid.text.trim()) ?? 0,
      notes: notes.text.trim(),
      createdAt: DateTime.now(),
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
      _toast('Invoice saved to Firestore.');
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
    final bytes = await _buildInvoicePdf(invoice);
    await Printing.layoutPdf(
      name: 'invoice-${invoice.number}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController(text: '0');

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
              validator: _required,
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
      label: Text('$label: ${_date.format(value)}'),
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
              Image.asset(
                _logoPath,
                height: 72,
                width: 180,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              Text(
                'Invoice',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
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
                  _TotalLine('Subtotal', _money.format(invoice.subtotal)),
                  _TotalLine(
                    'Total',
                    _money.format(invoice.total),
                    strong: true,
                  ),
                  _TotalLine('Paid', _money.format(invoice.paid)),
                  const Divider(),
                  _TotalLine(
                    'Amount Due',
                    _money.format(invoice.due),
                    strong: true,
                  ),
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
  const _Facts(this.invoice);

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _FactLine('Invoice #', invoice.number),
        _FactLine('Date', _date.format(invoice.date)),
        _FactLine('Due date', _date.format(invoice.dueDate)),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
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
                Expanded(flex: 5, child: Text(item.description)),
                Expanded(child: Text(item.quantity.toStringAsFixed(0))),
                Expanded(flex: 2, child: Text(_money.format(item.price))),
                Expanded(flex: 2, child: Text(_money.format(item.amount))),
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
                fontSize: strong ? 16 : 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                  fontSize: strong ? 18 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 980 ? 4 : (width > 620 ? 2 : 1);
        const spacing = 14.0;
        final childWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: childWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.lines,
    required this.icon,
    required this.onEdit,
  });

  final String title;
  final List<String> lines;
  final IconData icon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...lines
                .where((line) => line.trim().isNotEmpty)
                .map(
                  (line) =>
                      Text(line, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.invoice);

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
        '#${invoice.number} • ${invoice.client.name}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${_date.format(invoice.date)} • Due ${_money.format(invoice.due)}',
      ),
      trailing: Text(
        _money.format(invoice.total),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF92400E))),
    );
  }
}

Future<void> _showCompanyDialog(
  BuildContext context,
  InvoiceStore store, [
  Company? company,
]) async {
  final name = TextEditingController(text: company?.name ?? 'ZA Pictures');
  final address = TextEditingController(text: company?.address ?? '');
  final phone = TextEditingController(text: company?.phone ?? '');
  final email = TextEditingController(text: company?.email ?? '');
  await _showEntityDialog(
    context: context,
    title: company == null ? 'Add company' : 'Edit company',
    fields: [
      _DialogField('Company name', name),
      _DialogField('Address', address, lines: 3),
      _DialogField('Phone', phone),
      _DialogField('Email', email),
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

Future<void> _showClientDialog(
  BuildContext context,
  InvoiceStore store, [
  Client? client,
]) async {
  final name = TextEditingController(text: client?.name ?? '');
  final phone = TextEditingController(text: client?.phone ?? '');
  final email = TextEditingController(text: client?.email ?? '');
  final address = TextEditingController(text: client?.address ?? '');
  await _showEntityDialog(
    context: context,
    title: client == null ? 'Add client' : 'Edit client',
    fields: [
      _DialogField('Client name', name),
      _DialogField('Phone', phone),
      _DialogField('Email', email),
      _DialogField('Address', address, lines: 3),
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

Future<void> _showEntityDialog({
  required BuildContext context,
  required String title,
  required List<_DialogField> fields,
  required Future<void> Function() onSave,
}) async {
  final formKey = GlobalKey<FormState>();
  var saving = false;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: fields
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: field.controller,
                          minLines: field.lines,
                          maxLines: field.lines,
                          decoration: InputDecoration(labelText: field.label),
                          validator:
                              field.label.contains('name') ||
                                  field.label.contains('Company')
                              ? _required
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
                        await onSave();
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
      },
    ),
  );

  for (final field in fields) {
    field.controller.dispose();
  }
}

class _DialogField {
  const _DialogField(this.label, this.controller, {this.lines = 1});

  final String label;
  final TextEditingController controller;
  final int lines;
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
  return null;
}


