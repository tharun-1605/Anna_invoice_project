import 'package:flutter/material.dart';

import '../utils/pdf_generator.dart';
import 'app_view.dart';

class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.view, required this.onViewChanged});

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
          Image.asset(logoPath, height: 72, fit: BoxFit.contain),
          const SizedBox(height: 24),
          Text(
            'Invoice Studio',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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

class MobileBar extends StatelessWidget {
  const MobileBar({super.key, required this.view, required this.onViewChanged});

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
                  logoPath,
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
              Icon(icon, color: active ? Colors.white : const Color(0xFF4B5563)),
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
