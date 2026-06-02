import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key, required this.store, required this.packages});

  final InvoiceStore store;
  final List<StudioPackage> packages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Packages & Items',
          subtitle: 'Manage your predefined photo packages and items.',
          action: FilledButton.icon(
            onPressed: () => showPackageDialog(context, store),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add package'),
          ),
        ),
        const SizedBox(height: 18),
        if (packages.isEmpty)
          const Panel(title: 'Packages', child: EmptyState('Add a package'))
        else
          ResponsiveGrid(
            children: packages
                .map(
                  (pkg) => InfoCard(
                    title: pkg.name,
                    lines: [pkg.description, 'Price: ${money.format(pkg.price)}'],
                    icon: Icons.inventory_2_outlined,
                    onEdit: () => showPackageDialog(context, store, pkg),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
