import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/studio_package.dart';
import '../pages/client_ledger_page.dart';
import '../pages/clients_page.dart';
import '../pages/companies_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/invoice_composer.dart';
import '../pages/invoices_page.dart';
import '../pages/packages_page.dart';
import '../pages/reminders_page.dart';
import '../pages/sales_page.dart';
import '../services/invoice_store.dart';
import 'app_view.dart';

class AppContent extends StatelessWidget {
  const AppContent({
    super.key,
    required this.view,
    required this.store,
    required this.companies,
    required this.clients,
    required this.invoices,
    required this.packages,
    required this.loading,
    required this.onViewChanged,
    required this.onEditInvoice,
    required this.onViewLedger,
    this.invoiceToEdit,
    this.ledgerClient,
  });

  final AppView view;
  final InvoiceStore store;
  final List<Company> companies;
  final List<Client> clients;
  final List<Invoice> invoices;
  final List<StudioPackage> packages;
  final bool loading;
  final ValueChanged<AppView> onViewChanged;
  final ValueChanged<Invoice> onEditInvoice;
  final ValueChanged<Client> onViewLedger;
  final Invoice? invoiceToEdit;
  final Client? ledgerClient;

  @override
  Widget build(BuildContext context) {
    final page = switch (view) {
      AppView.dashboard => DashboardPage(
          invoices: invoices,
          companies: companies,
          clients: clients,
          packages: packages,
          loading: loading,
          onCreate: () => onViewChanged(AppView.create),
        ),
      AppView.companies => CompaniesPage(store: store, companies: companies),
      AppView.clients => ClientsPage(
          store: store,
          clients: clients,
          onViewLedger: onViewLedger,
        ),
      AppView.clientLedger => ClientLedgerPage(
              clients: clients,
              invoices: invoices,
              initialClient: ledgerClient,
            ),
      AppView.salesReport => SalesPage(invoices: invoices),
      AppView.invoices => InvoicesPage(
          invoices: invoices,
          store: store,
          onEdit: onEditInvoice,
        ),
      AppView.reminders => RemindersPage(
          invoices: invoices,
          store: store,
        ),
      AppView.packages => PackagesPage(store: store, packages: packages),
      AppView.create => InvoiceComposer(
          store: store,
          companies: companies,
          clients: clients,
          packages: packages,
          onSaved: () => onViewChanged(AppView.invoices),
          invoiceToEdit: invoiceToEdit,
        ),
    };

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
