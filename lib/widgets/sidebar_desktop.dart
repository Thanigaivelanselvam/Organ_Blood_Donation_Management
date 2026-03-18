import 'package:flutter/material.dart';

class SidebarDesktop extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final VoidCallback onToggleTheme;

  const SidebarDesktop({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Share Joy", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

          _item(Icons.dashboard, "Dashboard", 0),
          _item(Icons.people, "Donors", 1),
          _item(Icons.person_add, "Add Donor", 2),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text("Toggle Theme"),
            onTap: onToggleTheme,
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, int index) {
    return ListTile(
      selected: selectedIndex == index,
      leading: Icon(icon),
      title: Text(title),
      onTap: () => onSelect(index),
    );
  }
}