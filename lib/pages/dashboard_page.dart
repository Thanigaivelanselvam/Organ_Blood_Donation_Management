import 'package:flutter/material.dart';
import '../widgets/sidebar_desktop.dart';
import '../widgets/sidebar_mobile.dart';
import '../widgets/dashboard_body.dart';
import '../widgets/donors_body.dart';
import '../widgets/add_edit_body.dart';

class DashboardPage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;

  const DashboardPage({
    super.key,
    required this.darkMode,
    required this.onToggleTheme,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int index = 0;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: scaffoldKey,
      drawer: !isWide ? SidebarMobile(
        onSelect: (i) => setState(() => index = i),
        onToggleTheme: widget.onToggleTheme,
      ) : null,
      body: Row(
        children: [
          if (isWide)
            SidebarDesktop(
              selectedIndex: index,
              onSelect: (i) => setState(() => index = i),
              onToggleTheme: widget.onToggleTheme,
            ),
          Expanded(child: _getPage()),
        ],
      ),
    );
  }

  Widget _getPage() {
    switch (index) {
      case 0:
        return const DashboardBody();
      case 1:
        return const DonorsBody();
      case 2:
        return const AddEditBody();
      default:
        return const DashboardBody();
    }
  }
}