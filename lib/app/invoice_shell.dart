import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import 'app_content.dart';
import 'app_view.dart';
import 'navigation.dart';
import '../utils/download_helper.dart';

class InvoiceShell extends StatefulWidget {
  const InvoiceShell({super.key});

  @override
  State<InvoiceShell> createState() => _InvoiceShellState();
}

class _InvoiceShellState extends State<InvoiceShell> {
  late final InvoiceStore store;
  AppView view = AppView.dashboard;
  Invoice? invoiceToEdit;
  Client? ledgerClient;

  @override
  void initState() {
    super.initState();
    store = InvoiceStore(FirebaseFirestore.instance);
    DownloadHelper.requestStoragePermissionOnStartup();
  }

  void _changeView(AppView next) {
    setState(() {
      view = next;
      if (next != AppView.create) {
        invoiceToEdit = null;
      }
    });
  }

  void _editInvoice(Invoice invoice) {
    setState(() {
      invoiceToEdit = invoice;
      view = AppView.create;
    });
  }

  void _viewLedger(Client client) {
    setState(() {
      ledgerClient = client;
      view = AppView.clientLedger;
    });
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
                        companiesSnapshot.connectionState == ConnectionState.waiting ||
                            clientsSnapshot.connectionState == ConnectionState.waiting ||
                            invoicesSnapshot.connectionState == ConnectionState.waiting ||
                            packagesSnapshot.connectionState == ConnectionState.waiting;

                    return Scaffold(
                      body: SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;
                            final content = AppContent(
                              view: view,
                              store: store,
                              companies: companies,
                              clients: clients,
                              invoices: invoices,
                              packages: packages,
                              loading: loading,
                              onViewChanged: _changeView,
                              onEditInvoice: _editInvoice,
                              onViewLedger: _viewLedger,
                              invoiceToEdit: invoiceToEdit,
                              ledgerClient: ledgerClient,
                            );

                            final now = DateTime.now();
                            final pendingReminders = invoices.where((inv) {
                              return inv.type == 'Tax Invoice' && 
                                     inv.due > 0 && 
                                     now.isAfter(inv.dueDate) && 
                                     !inv.isReminderDismissed;
                            }).length;

                            if (!wide) {
                              return Column(
                                children: [
                                  MobileBar(view: view, onViewChanged: _changeView, pendingReminders: pendingReminders),
                                  Expanded(child: content),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                SideNav(view: view, onViewChanged: _changeView, pendingReminders: pendingReminders),
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
