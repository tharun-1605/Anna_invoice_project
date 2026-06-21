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
  final _venueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  StudioPackage? _selectedPackage;
  final Set<StudioItem> _selectedAddons = {};
  DateTime? _selectedDate;
  String? _selectedShootType = 'Portrait';
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
          'Requested on: ${dateFormatter.format(quote.createdAt)} • Total: ${money.format(quote.total)}',
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
                            'Selected Deliverables & Pricing',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 8),
                          ...quote.items.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(item.description)),
                                    Text(money.format(item.price)),
                                  ],
                                ),
                              )),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimated Total', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(money.format(quote.total), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _deleteQuote(quote),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete Request', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _viewPdf(quote),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('View PDF'),
                    ),
                    const SizedBox(width: 12),
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
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double total = 0.0;
    if (_selectedPackage != null) {
      total += _selectedPackage!.price;
    }
    for (final addon in _selectedAddons) {
      total += addon.price;
    }
    return total;
  }

  Future<void> _submitQuoteRequest(Company defaultCompany) async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a package first.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred shoot date.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create Client metadata (embedded in the Quote)
      final clientObj = Client(
        id: guestId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _venueCtrl.text.trim(),
      );

      // Create Quote Invoice Items
      final invoiceItems = [
        InvoiceItem(
          description: _selectedPackage!.name,
          quantity: 1.0,
          price: _selectedPackage!.price,
        ),
        ..._selectedAddons.map((item) => InvoiceItem(
          description: item.name,
          quantity: 1.0,
          price: item.price,
        )),
      ];

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
        dueDate: _selectedDate!,
        items: invoiceItems,
        paid: 0.0,
        notes: _notesCtrl.text.trim(),
        createdAt: DateTime.now(),
        payments: [],
        type: 'Quote',
        shootDate: _selectedDate,
        shootVenue: _venueCtrl.text.trim(),
        shootType: _selectedShootType,
      );
      await widget.store.saveInvoice(quote);

      // 2. Save matching Lead
      final lead = Lead(
        id: guestId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _venueCtrl.text.trim(),
        eventDate: dateFormatter.format(_selectedDate!),
        priority: 'High',
        reference: 'Quote Requested: ${_selectedPackage!.name}',
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
      _selectedPackage = null;
      _selectedAddons.clear();
      _selectedDate = null;
      _selectedShootType = 'Portrait';
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _venueCtrl.clear();
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
    final packages = widget.packages;
    final addons = widget.studioItems;
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
          Row(
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
              const SizedBox(width: 16),
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
            const Expanded(
              child: Center(
                child: EmptyState('No quote requests received yet.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: quoteInvoices.length,
                itemBuilder: (context, index) => _buildQuoteCard(quoteInvoices[index]),
              ),
            ),
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
          Row(
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
              const SizedBox(width: 16),
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
        
        // 1. Packages Selection
        Text(
          'Step 1: Choose Your Photography Package',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E3A8A),
              ),
        ),
        const SizedBox(height: 12),
        packages.isEmpty
            ? const EmptyState('No photography packages available.')
            : ResponsiveGrid(
                children: packages.map((pkg) => _buildPackageCard(pkg)).toList(),
              ),
        const SizedBox(height: 32),

        // 2. Add-ons Selection
        if (addons.isNotEmpty) ...[
          Text(
            'Step 2: Choose Optional Add-ons',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
          ),
          const SizedBox(height: 12),
          _buildAddonsSection(addons),
          const SizedBox(height: 32),
        ],

        // 3. Shoot & Contact Details Form
        Text(
          'Step 3: Tell Us About Your Shoot',
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

  Widget _buildPackageCard(StudioPackage pkg) {
    final isSelected = _selectedPackage?.id == pkg.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = pkg;
        });
      },
      child: GlassContainer(
        applyBlur: false,
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.4),
          width: isSelected ? 2.5 : 1,
        ),
        color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pkg.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                  else
                    const Icon(Icons.circle_outlined, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                pkg.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                money.format(pkg.price),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              if (pkg.deliverables.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'Includes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                ...pkg.deliverables.take(3).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddonsSection(List<StudioItem> addons) {
    return GlassContainer(
      applyBlur: false,
      color: Colors.white.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: addons.map((item) {
            final isAdded = _selectedAddons.contains(item);
            return FilterChip(
              avatar: Icon(
                isAdded ? Icons.add_circle : Icons.add_circle_outline,
                size: 16,
                color: isAdded ? Colors.white : const Color(0xFF2563EB),
              ),
              label: Text('${item.name} (+${money.format(item.price)})'),
              selected: isAdded,
              selectedColor: const Color(0xFF2563EB),
              labelStyle: TextStyle(
                color: isAdded ? Colors.white : Colors.black87,
                fontWeight: isAdded ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedAddons.add(item);
                  } else {
                    _selectedAddons.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal & Shoot details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 16),
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
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedShootType,
                      decoration: const InputDecoration(labelText: 'Shoot Type'),
                      items: ['Portrait', 'Wedding', 'Pre-Wedding', 'Engagement', 'Event', 'Maternity', 'Newborn', 'Corporate', 'Other']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedShootType = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _selectedDate == null
                            ? 'Preferred Date *'
                            : 'Date: ${dateFormatter.format(_selectedDate!)}',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _venueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Event Venue / Address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: requiredField,
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
            ],
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
            
            // Package line
            if (_selectedPackage != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedPackage!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(money.format(_selectedPackage!.price)),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              const Text(
                'No package selected',
                style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
              ),
            ],
            
            // Add-ons list
            if (_selectedAddons.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Add-ons:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              ..._selectedAddons.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '+ ${item.name}',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                        Text(money.format(item.price), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
            ],
            
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Total',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  money.format(_totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
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
          width: 500,
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
                'Thank you, ${_nameCtrl.text.trim()}! Your request for the ${_selectedPackage?.name} package on ${_selectedDate != null ? dateFormatter.format(_selectedDate!) : ""} has been received.',
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
