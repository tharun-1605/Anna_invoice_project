import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/lead.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/glass_container.dart';
import '../utils/pdf_generator.dart';
import 'package:printing/printing.dart';

class ClientBookingPage extends StatefulWidget {
  const ClientBookingPage({
    super.key,
    required this.store,
    required this.companies,
    required this.packages,
    required this.studioItems,
    this.isPublicPortal = false,
    this.invoices = const [],
  });

  final InvoiceStore store;
  final List<Company> companies;
  final List<StudioPackage> packages;
  final List<StudioItem> studioItems;
  final bool isPublicPortal;
  final List<Invoice> invoices;

  @override
  State<ClientBookingPage> createState() => _ClientBookingPageState();
}

class _ClientBookingPageState extends State<ClientBookingPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final Set<String> _selectedServices = {};
  final List<BookingEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _events.add(BookingEvent());
  }

  static const List<String> _shootTypes = [
    '60th Wedding',
    'Baby Shower',
    'Birthday',
    'Corporate Events',
    'Ear Piercing Ceremony',
    'Engagement',
    'Get together',
    'House Warming',
    'Naming Ceremony',
    'Outdoor Post-Wedding',
    'Outdoor Pre-Wedding',
    'Puberty',
    'Reception',
    'Religious Events',
    'Rituals - Bride',
    'Rituals - Groom',
    'Wedding',
  ];

  static const List<String> _availableServices = [
    'Traditional Photography',
    'Traditional Videography',
    'Candid Photography',
    'Candid Videography',
    'Cinematography',
    'Drone Shoot',
    'Standard Album',
    'Premium Album',
    'Luxury Album',
    'Pre-Wedding Shoot',
    'Post-Wedding Shoot',
    'Live Streaming',
    'LED Wall',
    'Photo Booth',
  ];
  bool _submitted = false;
  bool _submitting = false;
  int _activeAdminTab = 0;

  String _generateNextInvoiceNumber() {
    int maxNum = 0;
    for (final inv in widget.invoices) {
      if (inv.type != 'Quote') {
        final num = int.tryParse(inv.number);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    return maxNum == 0 ? '1' : (maxNum + 1).toString();
  }

  Future<void> _convertToInvoice(Invoice quote) async {
    final nextNum = _generateNextInvoiceNumber();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert Quote to Invoice?'),
        content: Text(
          'This will convert Quote ${quote.number} to Tax Invoice #$nextNum and move it to the Invoices page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final updatedInvoice = Invoice(
        id: quote.id,
        number: nextNum,
        company: quote.company,
        client: quote.client,
        date: DateTime.now(),
        dueDate: quote.dueDate,
        items: quote.items,
        paid: quote.paid,
        notes: quote.notes,
        createdAt: quote.createdAt,
        payments: quote.payments,
        discountAmount: quote.discountAmount,
        type: 'Tax Invoice',
        isReminderDismissed: quote.isReminderDismissed,
        shootDate: quote.shootDate,
        shootVenue: quote.shootVenue,
        shootType: quote.shootType,
      );
      await widget.store.saveInvoice(updatedInvoice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote ${quote.number} converted to Tax Invoice #$nextNum!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteQuote(Invoice quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote Request?'),
        content: Text('Are you sure you want to delete this quote request? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.store.deleteInvoice(quote.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote request deleted.')),
        );
      }
    }
  }

  void _viewPdf(Invoice quote) {
    final pdfFuture = buildInvoicePdf(quote);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Quote ${quote.number}')),
          body: PdfPreview(
            build: (format) => pdfFuture,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteCard(Invoice quote) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          quote.client.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Requested on: ${dateFormatter.format(quote.createdAt)}',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF2563EB),
          child: Icon(Icons.description_outlined, color: Colors.white),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client Information',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 8),
                          Text('Phone: ${quote.client.phone}'),
                          Text('Email: ${quote.client.email}'),
                          if (quote.client.address.isNotEmpty) Text('Address: ${quote.client.address}'),
                          const SizedBox(height: 16),
                          const Text(
                            'Shoot Details',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 8),
                          if (quote.shootType != null) Text('Shoot Type: ${quote.shootType}'),
                          if (quote.shootDate != null) Text('Date: ${dateFormatter.format(quote.shootDate!)}'),
                          if (quote.shootVenue != null) Text('Venue: ${quote.shootVenue}'),
                          if (quote.notes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Special Requests: ${quote.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Services',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 8),
                          ...quote.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item.description)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _deleteQuote(quote),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete Request', style: TextStyle(color: Colors.red)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _viewPdf(quote),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('View PDF'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _convertToInvoice(quote),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Convert to Invoice'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    for (final event in _events) {
      event.dispose();
    }
    super.dispose();
  }

  Future<void> _submitQuoteRequest(Company defaultCompany) async {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_events.any((e) => e.date == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred date for all events.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      
      // Determine earliest event date for primary shootDate
      DateTime? earliestDate;
      for (final event in _events) {
        if (event.date != null) {
          if (earliestDate == null || event.date!.isBefore(earliestDate)) {
            earliestDate = event.date;
          }
        }
      }

      final primaryShootType = _events.map((e) => e.shootType).whereType<String>().join(', ');
      final primaryShootVenue = _events.map((e) => e.venueCtrl.text.trim()).join('; ');

      // Create event summary for notes
      final eventsSummary = _events.asMap().entries.map((entry) {
        final idx = entry.key + 1;
        final event = entry.value;
        final dateStr = event.date != null ? dateFormatter.format(event.date!) : 'TBD';
        return 'Event $idx: ${event.shootType} on $dateStr at ${event.venueCtrl.text.trim()}';
      }).join('\n');

      final combinedNotes = 'Event Schedule:\n$eventsSummary\n\n'
          'Special Requests / Notes:\n${_notesCtrl.text.trim()}';

      // Create Client metadata (embedded in the Quote)
      final clientObj = Client(
        id: guestId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: primaryShootVenue,
      );

      // Create Quote Invoice Items
      final invoiceItems = _selectedServices.map((serviceName) {
        final matchingItem = widget.studioItems.firstWhere(
          (item) => item.name.toLowerCase() == serviceName.toLowerCase(),
          orElse: () => StudioItem(id: '', name: serviceName, price: 0.0),
        );
        return InvoiceItem(
          description: serviceName,
          quantity: 1.0,
          price: matchingItem.price,
        );
      }).toList();

      // Auto-generate invoice number (Quote format Q-YYYYMMDDHHMM)
      final quoteNumber = 'Q-${DateTime.now().year}'
          '${DateTime.now().month.toString().padLeft(2, '0')}'
          '${DateTime.now().day.toString().padLeft(2, '0')}'
          '${DateTime.now().minute.toString().padLeft(2, '0')}';

      // 1. Save pending Quote Invoice
      final quote = Invoice(
        id: '', // Auto-generated by Firestore
        number: quoteNumber,
        company: defaultCompany,
        client: clientObj,
        date: DateTime.now(),
        dueDate: earliestDate ?? DateTime.now(),
        items: invoiceItems,
        paid: 0.0,
        notes: combinedNotes.trim(),
        createdAt: DateTime.now(),
        payments: [],
        type: 'Quote',
        shootDate: earliestDate,
        shootVenue: primaryShootVenue,
        shootType: primaryShootType,
      );
      await widget.store.saveInvoice(quote);

      // 2. Save matching Lead
      final lead = Lead(
        id: guestId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: primaryShootVenue,
        eventDate: _events.map((e) => e.date != null ? dateFormatter.format(e.date!) : 'TBD').join(', '),
        priority: 'High',
        reference: 'Quote Requested:\n$eventsSummary\n\nServices: ${_selectedServices.join(", ")}',
      );
      await widget.store.saveLead(lead);

      setState(() {
        _submitted = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting quote request: $e')),
      );
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _selectedServices.clear();
      for (final event in _events) {
        event.dispose();
      }
      _events.clear();
      _events.add(BookingEvent());
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _notesCtrl.clear();
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _buildSuccessScreen();
    }

    if (widget.companies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Please set up at least one company in Settings before requesting bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    final defaultCompany = widget.companies.first;
    final quoteInvoices = widget.invoices.where((inv) => inv.type == 'Quote').toList();

    // If viewing in the admin app and the active tab is "Quote Requests" (0), show the list of quote requests.
    if (!widget.isPublicPortal && _activeAdminTab == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Booking Portal & Leads',
            subtitle: 'Manage public booking requests and convert client quotes to tax invoices.',
            action: OutlinedButton.icon(
              onPressed: () {
                String scheme = Uri.base.scheme;
                String host = Uri.base.host;
                String port = Uri.base.port != 80 && Uri.base.port != 443 && Uri.base.port != 0 ? ':${Uri.base.port}' : '';
                
                if (scheme == 'file' || host.isEmpty) {
                  scheme = 'http';
                  host = 'localhost';
                  port = ':8080';
                }
                
                final portalUrl = "$scheme://$host$port/#/booking";
                Clipboard.setData(ClipboardData(text: portalUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Public booking link copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Copy Public Link'),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _activeAdminTab = 0),
                icon: Icon(Icons.list_alt_outlined, color: _activeAdminTab == 0 ? const Color(0xFF2563EB) : Colors.grey),
                label: Text(
                  'Quote Requests (${quoteInvoices.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _activeAdminTab == 0 ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _activeAdminTab = 1),
                icon: Icon(Icons.preview_outlined, color: _activeAdminTab == 1 ? const Color(0xFF2563EB) : Colors.grey),
                label: Text(
                  'Portal Form Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _activeAdminTab == 1 ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (quoteInvoices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: EmptyState('No quote requests received yet.'),
              ),
            )
          else
            ...quoteInvoices.map((quote) => _buildQuoteCard(quote)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isPublicPortal) ...[
          PageHeader(
            title: 'Booking Portal & Leads',
            subtitle: 'Manage public booking requests and convert client quotes to tax invoices.',
            action: OutlinedButton.icon(
              onPressed: () {
                String scheme = Uri.base.scheme;
                String host = Uri.base.host;
                String port = Uri.base.port != 80 && Uri.base.port != 443 && Uri.base.port != 0 ? ':${Uri.base.port}' : '';
                
                if (scheme == 'file' || host.isEmpty) {
                  scheme = 'http';
                  host = 'localhost';
                  port = ':8080';
                }
                
                final portalUrl = "$scheme://$host$port/#/booking";
                Clipboard.setData(ClipboardData(text: portalUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Public booking link copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Copy Public Link'),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _activeAdminTab = 0),
                icon: Icon(Icons.list_alt_outlined, color: _activeAdminTab == 0 ? const Color(0xFF2563EB) : Colors.grey),
                label: Text(
                  'Quote Requests (${quoteInvoices.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _activeAdminTab == 0 ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _activeAdminTab = 1),
                icon: Icon(Icons.preview_outlined, color: _activeAdminTab == 1 ? const Color(0xFF2563EB) : Colors.grey),
                label: Text(
                  'Portal Form Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _activeAdminTab == 1 ? const Color(0xFF2563EB) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ] else ...[
          PageHeader(
            title: 'Interactive Quote Builder',
            subtitle: 'Configure your photography package and request a custom quote instantly.',
            action: null,
          ),
          const SizedBox(height: 24),
        ],
        
        Text(
          'Configure Your Quote',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 750;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildDetailsForm(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildSummaryCard(defaultCompany),
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailsForm(),
                  const SizedBox(height: 24),
                  _buildSummaryCard(defaultCompany),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return GlassContainer(
      applyBlur: false,
      color: Colors.white.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personal & Shoot details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Your Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: requiredField,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number *',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: requiredField,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: requiredField,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: requiredField,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email Address *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: requiredField,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Event Schedule *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),
                  ..._events.indexed.map((entry) {
                    final index = entry.$1;
                    final event = entry.$2;
                    return Container(
                      key: ValueKey(event),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Event #${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 14,
                                ),
                              ),
                              if (_events.length > 1)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      event.dispose();
                                      _events.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Remove Event',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, eventConstraints) {
                              final wideEvent = eventConstraints.maxWidth >= 500;
                              final typeDropdown = DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: event.shootType,
                                decoration: const InputDecoration(
                                  labelText: 'Shoot Type *',
                                  isDense: true,
                                ),
                                items: _shootTypes
                                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    event.shootType = val;
                                  });
                                },
                              );
                              final datePickerButton = OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now().add(const Duration(days: 7)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      event.date = picked;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                                label: Text(
                                  event.date == null
                                      ? 'Preferred Date *'
                                      : dateFormatter.format(event.date!),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                              );

                              if (wideEvent) {
                                return Row(
                                  children: [
                                    Expanded(child: typeDropdown),
                                    const SizedBox(width: 14),
                                    Expanded(child: datePickerButton),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    typeDropdown,
                                    const SizedBox(height: 14),
                                    datePickerButton,
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: event.venueCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Event Venue / Address *',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              isDense: true,
                            ),
                            validator: requiredField,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _events.add(BookingEvent());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Event / Date'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Special Requests / Event Details',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Services Required *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, gridConstraints) {
                      final cols = gridConstraints.maxWidth >= 600 ? 2 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: cols == 2 ? 4.5 : 5.5,
                        ),
                        itemCount: _availableServices.length,
                        itemBuilder: (context, index) {
                          final service = _availableServices[index];
                          final isSelected = _selectedServices.contains(service);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedServices.remove(service);
                                } else {
                                  _selectedServices.add(service);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB).withOpacity(0.08)
                                    : Colors.white.withOpacity(0.4),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_box_outlined
                                        : Icons.check_box_outline_blank,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      service,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Company defaultCompany) {
    return GlassContainer(
      applyBlur: false,
      color: Colors.white.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quote Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
            ),
            const Divider(height: 24),
            
            // Services list
            if (_selectedServices.isNotEmpty) ...[
              ..._selectedServices.map((serviceName) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              const Text(
                'No services selected',
                style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
              ),
            ],
            
            const SizedBox(height: 24),
            
            _submitting
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: () => _submitQuoteRequest(defaultCompany),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Request Quote'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2563EB),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassContainer(
          applyBlur: false,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          color: Colors.white.withOpacity(0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Quote Request Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you, ${_nameCtrl.text.trim()}! Your quote request has been successfully submitted.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'We will review details and follow up with a finalized proposal invoice shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _resetForm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: const Text('Build Another Quote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookingEvent {
  BookingEvent({
    this.shootType = 'Wedding',
    this.date,
    String venue = '',
  }) : venueCtrl = TextEditingController(text: venue);

  String? shootType;
  DateTime? date;
  final TextEditingController venueCtrl;

  void dispose() {
    venueCtrl.dispose();
  }
}

