import 'package:flutter/material.dart';

class SidebarMobile extends StatelessWidget {
  final Function(int) onSelect;
  final VoidCallback onToggleTheme;

  const SidebarMobile({
    super.key,
    required this.onSelect,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(child: Text("Share Joy")),

          ListTile(
            title: const Text("Dashboard"),
            onTap: () => onSelect(0),
          ),
          ListTile(
            title: const Text("Donors"),
            onTap: () => onSelect(1),
          ),
          ListTile(
            title: const Text("Add Donor"),
            onTap: () => onSelect(2),
          ),

          const Divider(),

          ListTile(
            title: const Text("Toggle Theme"),
            onTap: onToggleTheme,
          ),
        ],
      ),
    );
  }
}