import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/lead.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import 'app_content.dart';
import 'app_view.dart';
import 'navigation.dart';
import '../utils/download_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/lock_screen.dart';

class InvoiceShell extends StatefulWidget {
  const InvoiceShell({super.key});

  @override
  State<InvoiceShell> createState() => _InvoiceShellState();
}

class _InvoiceShellState extends State<InvoiceShell> with WidgetsBindingObserver {
  late final InvoiceStore store;
  AppView view = AppView.dashboard;
  Invoice? invoiceToEdit;
  Client? ledgerClient;
  String initialInvoiceType = 'Tax Invoice';
  Client? initialComposerClient;
  bool isPublicPortal = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = InvoiceStore(FirebaseFirestore.instance);
    DownloadHelper.requestStoragePermissionOnStartup();

    final uri = Uri.base;
    final hasBookingQuery = uri.fragment.contains('booking') || 
                            uri.path.contains('booking') || 
                            uri.queryParameters.containsKey('booking') ||
                            uri.fragment.contains('portal') ||
                            uri.path.contains('portal') ||
                            uri.queryParameters.containsKey('portal');
    if (hasBookingQuery) {
      view = AppView.bookingPortal;
      isPublicPortal = true;
    }

    _checkAppLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAppLock() async {
    if (isPublicPortal) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? false;
    if (enabled) {
      setState(() {
        _isLocked = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isPublicPortal) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _checkAppLock();
    }
  }

  void _changeView(AppView next) {
    setState(() {
      view = next;
      if (next != AppView.create) {
        invoiceToEdit = null;
        initialInvoiceType = 'Tax Invoice';
        initialComposerClient = null;
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

  void _createQuote(Lead lead) {
    setState(() {
      initialInvoiceType = 'Quote';
      initialComposerClient = Client(
        id: 'lead_${lead.id}',
        name: '${lead.name} (Lead)',
        phone: lead.phone,
        email: lead.email,
        address: lead.address,
        fromLead: true,
      );
      view = AppView.create;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return LockScreen(
        onUnlocked: () {
          setState(() {
            _isLocked = false;
          });
        },
      );
    }

    return StreamBuilder<List<Company>>(
      stream: store.companies(),
      builder: (context, companiesSnapshot) {
        return StreamBuilder<List<Lead>>(
          stream: store.leads(),
          builder: (context, leadsSnapshot) {
            return StreamBuilder<List<Client>>(
              stream: store.clients(),
              builder: (context, clientsSnapshot) {
                return StreamBuilder<List<Invoice>>(
                  stream: store.invoices(),
                  builder: (context, invoicesSnapshot) {
                    return StreamBuilder<List<StudioPackage>>(
                      stream: store.packages(),
                      builder: (context, packagesSnapshot) {
                        return StreamBuilder<List<StudioItem>>(
                          stream: store.studioItems(),
                          builder: (context, studioItemsSnapshot) {
                            final companies = companiesSnapshot.data ?? [];
                            final leads = leadsSnapshot.data ?? [];
                            final clients = clientsSnapshot.data ?? [];
                            final invoices = invoicesSnapshot.data ?? [];
                            final packages = packagesSnapshot.data ?? [];
                            final studioItems = studioItemsSnapshot.data ?? [];
                            final loading =
                                companiesSnapshot.connectionState == ConnectionState.waiting ||
                                    leadsSnapshot.connectionState == ConnectionState.waiting ||
                                    clientsSnapshot.connectionState == ConnectionState.waiting ||
                                    invoicesSnapshot.connectionState == ConnectionState.waiting ||
                                    packagesSnapshot.connectionState == ConnectionState.waiting ||
                                    studioItemsSnapshot.connectionState == ConnectionState.waiting;

                    return PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, result) async {
                        if (didPop) return;
                        final shouldPop = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Exit App'),
                            content: const Text('Are you sure you want to exit the app?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        ) ?? false;
                        
                        if (shouldPop && context.mounted) {
                          SystemNavigator.pop();
                        }
                      },
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        extendBodyBehindAppBar: true,
                        body: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE0EAFC),
                                    Color(0xFFCFDEF3),
                                    Color(0xFFFDEBEE),
                                    Color(0xFFE8F5E9),
                                  ],
                                  stops: [0.0, 0.4, 0.7, 1.0],
                                ),
                              ),
                            ),
                            SafeArea(
                              child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;
                            final content = AppContent(
                              view: view,
                              store: store,
                              companies: companies,
                              leads: leads,
                              clients: clients,
                              invoices: invoices,
                              packages: packages,
                              studioItems: studioItems,
                              loading: loading,
                              onViewChanged: _changeView,
                              onEditInvoice: _editInvoice,
                              onViewLedger: _viewLedger,
                              onCreateQuote: _createQuote,
                              invoiceToEdit: invoiceToEdit,
                              ledgerClient: ledgerClient,
                              initialInvoiceType: initialInvoiceType,
                              initialComposerClient: initialComposerClient,
                              isPublicPortal: isPublicPortal,
                            );

                            final now = DateTime.now();
                            final pendingReminders = invoices.where((inv) {
                              return inv.type == 'Tax Invoice' && 
                                     inv.due > 0 && 
                                     now.isAfter(inv.dueDate) && 
                                     !inv.isReminderDismissed;
                            }).length;

                            if (isPublicPortal) {
                              return content;
                            }

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
                    ],
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
      },
    );
      },
    );
  }
}

