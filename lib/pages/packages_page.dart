import 'package:flutter/material.dart';

import '../dialogs/entity_dialog.dart';
import '../models/studio_item.dart';
import '../models/studio_package.dart';
import '../services/invoice_store.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';

class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key, required this.store, required this.packages, required this.studioItems});

  final InvoiceStore store;
  final List<StudioPackage> packages;
  final List<StudioItem> studioItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Packages & Items',
          subtitle: 'Manage your predefined photo packages and standalone items.',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () => showStudioItemDialog(context, store),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add item'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => showPackageDialog(context, store),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add package'),
              ),
            ],
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
                    onDelete: () async {
                      final confirm = await confirmDelete(context, pkg.name);
                      if (confirm == true) {
                        await store.deletePackage(pkg.id);
                      }
                    },
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 32),
        Text(
          'Standalone Items',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        if (studioItems.isEmpty)
          const Panel(title: 'Items', child: EmptyState('Add a standalone item'))
        else
          ResponsiveGrid(
            children: studioItems
                .map(
                  (item) => InfoCard(
                    title: item.name,
                    lines: ['Price: ${money.format(item.price)}'],
                    icon: Icons.sell_outlined,
                    onEdit: () => showStudioItemDialog(context, store, item),
                    onDelete: () async {
                      final confirm = await confirmDelete(context, item.name);
                      if (confirm == true) {
                        await store.deleteStudioItem(item.id);
                      }
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
