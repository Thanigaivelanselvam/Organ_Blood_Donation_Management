import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:organ_blood_donation_management/firebase_options.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      runApp(const MyApp());
    } catch (e, stack) {
      print('Error during initialization: $e\n$stack');
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to initialize app',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Error: $e'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => main(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    print('Uncaught error: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Share Joy — Donation Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
        brightness: Brightness.dark,
      ),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: DashboardPage(
        darkMode: _dark,
        onToggleTheme: () => setState(() => _dark = !_dark),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;

  const DashboardPage({
    required this.darkMode,
    required this.onToggleTheme,
    Key? key
  }) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CollectionReference donorsCol =
  FirebaseFirestore.instance.collection('donors');
  final CollectionReference alertsCol =
  FirebaseFirestore.instance.collection('alerts');

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _cityC = TextEditingController();
  final _bloodC = TextEditingController();
  final _organsC = TextEditingController();
  bool _available = true;
  bool _loading = false;
  String _editingDocId = '';

  // Search & filters
  final _searchC = TextEditingController();
  String _filterBlood = 'All';
  String _filterCity = 'All';
  List<String> _citiesCache = ['All'];

  // Navigation state
  int _selectedMenuIndex = 0; // 0 Dashboard, 1 Donors, 2 Add/Edit
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Utils
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameC.clear();
    _phoneC.clear();
    _cityC.clear();
    _bloodC.clear();
    _organsC.clear();
    _available = true;
    _editingDocId = '';
  }

  Future<void> _addOrUpdateDonor() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final organsList = _organsC.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    final now = FieldValue.serverTimestamp();
    final data = {
      'name': _nameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'city': _cityC.text.trim(),
      'bloodGroup': _bloodC.text.trim().toUpperCase(),
      'organs': organsList,
      'available': _available,
      'updatedAt': now,
      'createdAt': now,
    };

    try {
      if (_editingDocId.isEmpty) {
        await donorsCol.add(data);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Donor added')));
        }
      } else {
        await donorsCol.doc(_editingDocId).set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Donor updated')));
        }
      }
      _clearForm();
      setState(() => _selectedMenuIndex = 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving donor: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteDonor(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Donor'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await donorsCol.doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Donor deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _startEditing(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    _editingDocId = doc.id;
    _nameC.text = (d['name'] ?? '').toString();
    _phoneC.text = (d['phone'] ?? '').toString();
    _cityC.text = (d['city'] ?? '').toString();
    _bloodC.text = (d['bloodGroup'] ?? '').toString();
    final organs =
        (d['organs'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ??
            '';
    _organsC.text = organs;
    _available = (d['available'] ?? true) == true;
    setState(() => _selectedMenuIndex = 2);
  }

  Future<void> _broadcastEmergencyAlert(String message) async {
    try {
      await alertsCol.add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'sentBy': 'web-admin',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Alert created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Alert failed: $e')));
      }
    }
  }

  // Stats UI
  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Donors stream + local filters
  Widget _donorsList() {
    final stream = donorsCol.orderBy('updatedAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        // build cities cache
        final cities = docs
            .map((d) => (d['city'] ?? '').toString())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        _citiesCache = ['All', ...cities];

        final s = _searchC.text.trim().toLowerCase();
        docs = docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final bg = (d['bloodGroup'] ?? '').toString().toUpperCase();
          final city = (d['city'] ?? '').toString();
          if (_filterBlood != 'All' && bg != _filterBlood) return false;
          if (_filterCity != 'All' && city != _filterCity) return false;
          if (s.isEmpty) return true;
          final hay =
          '${d['name'] ?? ''} ${d['phone'] ?? ''} ${city} ${bg} ${(d['organs'] as List<dynamic>?)?.join(' ') ?? ''}'
              .toLowerCase();
          return hay.contains(s);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
              child: Text('No donors match your search/filters.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;
            final name = (d['name'] ?? 'Unknown').toString();
            final phone = (d['phone'] ?? '-').toString();
            final city = (d['city'] ?? '-').toString();
            final bg = (d['bloodGroup'] ?? '-').toString();
            final organs = (d['organs'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .join(', ') ??
                '-';
            final available = (d['available'] ?? true) == true;
            final updatedAt = d['updatedAt'] as Timestamp?;
            final createdAt = d['createdAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.red.shade50],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔝 HEADER
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.red.shade100,
                        child: Text(
                          bg,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(city,
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),

                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _startEditing(doc)),
                      IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteDonor(doc.id)),
                    ],
                  ),

                  const Divider(),

                  // 💉 DETAILS
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text(organs)),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16),
                      const SizedBox(width: 6),
                      Text(phone),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Added: ${_formatTimestamp(createdAt)}",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 8),

                  // ✅ STATUS + ACTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(bg),
                        backgroundColor: Colors.red.shade100,
                      ),
                      Icon(
                        available ? Icons.check_circle : Icons.cancel,
                        color: available ? Colors.green : Colors.red,
                      )
                    ],
                  ),
                ],
              ),
            );          },
        );
      },
    );
  }

  // Sidebar for desktop
  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share Joy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    )),
                const SizedBox(height: 4),
                Text('Organ & Blood Donation',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Navigation Items
          _buildNavItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            index: 0,
          ),
          _buildNavItem(
            icon: Icons.people,
            label: 'Donors',
            index: 1,
          ),
          _buildNavItem(
            icon: Icons.person_add,
            label: _editingDocId.isEmpty ? 'Add Donor' : 'Edit Donor',
            index: 2,
          ),

          const Divider(height: 32),

          // Theme Toggle
          ListTile(
            leading: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Toggle Theme'),
            onTap: () {
              widget.onToggleTheme();
            },
          ),

          // Emergency Alert
          ListTile(
            leading: const Icon(Icons.notification_important, color: Colors.red),
            title: const Text('Emergency Alert'),
            onTap: () {
              _showEmergencyAlertDialog();
            },
          ),

          const Spacer(),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: Web Admin',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Drawer for mobile
  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share Joy',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                  const SizedBox(height: 4),
                  Text('Organ & Blood Donation',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Navigation Items
            _buildNavItem(
              icon: Icons.dashboard,
              label: 'Dashboard',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.people,
              label: 'Donors',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.person_add,
              label: _editingDocId.isEmpty ? 'Add Donor' : 'Edit Donor',
              index: 2,
            ),

            const Divider(height: 32),

            // Theme Toggle
            ListTile(
              leading: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
              title: const Text('Toggle Theme'),
              onTap: () {
                widget.onToggleTheme();
                Navigator.pop(context);
              },
            ),

            // Emergency Alert
            ListTile(
              leading: const Icon(Icons.notification_important, color: Colors.red),
              title: const Text('Emergency Alert'),
              onTap: () {
                Navigator.pop(context);
                _showEmergencyAlertDialog();
              },
            ),

            const Spacer(),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin: Web Admin',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final selected = _selectedMenuIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        selected: selected,
        onTap: () {
          setState(() {
            _selectedMenuIndex = index;
            if (index != 2) {
              _clearForm();
            }
          });
          // Close drawer if it's open
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showEmergencyAlertDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Emergency Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send an emergency alert to all donors:'),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Enter alert message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _broadcastEmergencyAlert(
                ctrl.text.trim().isEmpty
                    ? 'Emergency: Immediate donors needed'
                    : ctrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;
    final isMediumScreen = MediaQuery.of(context).size.width >= 800 &&
        MediaQuery.of(context).size.width < 1200;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          StreamBuilder<QuerySnapshot>(
            stream: donorsCol.snapshots(),
            builder: (context, snap) {
              final total = snap.hasData ? snap.data!.docs.length : 0;
              final available = snap.hasData
                  ? snap.data!.docs
                  .where((d) => (d['available'] ?? true) == true)
                  .length
                  : 0;
              final Map<String, int> counts = {};
              if (snap.hasData) {
                for (var d in snap.data!.docs) {
                  final bg = (d['bloodGroup'] ?? 'Unknown').toString();
                  counts[bg] = (counts[bg] ?? 0) + 1;
                }
              }

              final sortedCounts = counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              if (isSmallScreen) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard('Total', '$total', Icons.people),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _statCard('Available', '$available', Icons.bloodtype),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Blood Groups',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: sortedCounts.take(4).map((e) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      '${e.key}: ${e.value}',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (isMediumScreen) {
                return Row(
                  children: [
                    Expanded(
                      child: _statCard('Total Donors', '$total', Icons.people),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard('Available Now', '$available', Icons.bloodtype),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Top Blood Groups',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (sortedCounts.isEmpty)
                                const Text('-'),
                              for (var e in sortedCounts.take(3))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('${e.key}: ${e.value}'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _statCard('Total Donors', '$total', Icons.people),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _statCard('Available Now', '$available', Icons.bloodtype),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Blood Groups',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (sortedCounts.isEmpty)
                              const Text('-'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: sortedCounts.take(6).map((e) {
                                return Chip(
                                  label: Text('${e.key}: ${e.value}'),
                                  backgroundColor: Colors.red.shade50,
                                  labelStyle: TextStyle(color: Colors.red.shade700),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Search and filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isSmallScreen
                  ? Column(
                children: [
                  TextField(
                    controller: _searchC,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search donors...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 400) {
                        // Mobile → stack vertically
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _filterBlood,
                              decoration: const InputDecoration(
                                labelText: 'Blood Group',
                                border: OutlineInputBorder(),
                              ),
                              items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _filterCity,
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                              ),
                              items: _citiesCache
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _filterCity = v ?? 'All'),
                            ),
                          ],
                        );
                      } else {
                        // Tablet/Desktop → side by side
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterBlood,
                                decoration: const InputDecoration(
                                  labelText: 'Blood Group',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _filterCity,
                                decoration: const InputDecoration(
                                  labelText: 'City',
                                  border: OutlineInputBorder(),
                                ),
                                items: _citiesCache
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) => setState(() => _filterCity = v ?? 'All'),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchC,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search donors by name, phone, organ, city...',
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterBlood,
                    items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterCity,
                    items: _citiesCache
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterCity = v ?? 'All'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Donors list
          Expanded(child: _donorsList()),
        ],
      ),
    );
  }

  Widget _donorsBody() {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Donors',
                    style: isSmallScreen
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.headlineMedium),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _clearForm();
                  setState(() => _selectedMenuIndex = 2);
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Donor'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isSmallScreen
                  ? Column(
                children: [
                  TextField(
                    controller: _searchC,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search donors...',
                        border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _filterBlood,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
                  ),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchC,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search donors...',
                          border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterBlood,
                    items: ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(child: _donorsList()),
        ],
      ),
    );
  }

  Widget _addEditBody() {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? double.infinity : 900,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingDocId.isEmpty
                          ? 'Register New Donor'
                          : 'Edit Donor',
                      style: isSmallScreen
                          ? Theme.of(context).textTheme.headlineSmall
                          : Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameC,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter name'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneC,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter phone'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    isSmallScreen
                        ? Column(
                      children: [
                        TextFormField(
                          controller: _cityC,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _bloodC,
                          decoration: const InputDecoration(
                            labelText: 'Blood group (e.g. O+)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    )
                        : Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityC,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _bloodC,
                            decoration: const InputDecoration(
                              labelText: 'Blood group (e.g. O+)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _organsC,
                      decoration: const InputDecoration(
                        labelText: 'Organs (comma separated, e.g. kidney, liver)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Available'),
                            const SizedBox(width: 6),
                            Switch(
                              value: _available,
                              onChanged: (v) => setState(() => _available = v),
                            ),
                          ],
                        ),

                        ElevatedButton.icon(
                          onPressed: _addOrUpdateDonor,
                          icon: const Icon(Icons.save),
                          label: Text(_editingDocId.isEmpty ? 'Add' : 'Update'),
                        ),

                        OutlinedButton(
                          onPressed: () {
                            _clearForm();
                            setState(() => _selectedMenuIndex = 1);
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _cityC.dispose();
    _bloodC.dispose();
    _organsC.dispose();
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isWideScreen ? _buildMobileDrawer() : null,
      appBar: !isWideScreen
          ? AppBar(
        title: const Text('Share Joy — Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.warning),
            onPressed: () => _showEmergencyAlertDialog(),
            tooltip: 'Quick Alert',
          ),
        ],
      )
          : null,
      body: Row(
        children: [
          if (isWideScreen) _buildDesktopSidebar(),
          Expanded(
            child: Column(
              children: [
                // Top bar for wide screens
                if (isWideScreen)
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Text('Share Joy — Admin Dashboard',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        IconButton(
                          icon: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
                          onPressed: widget.onToggleTheme,
                          tooltip: 'Toggle Theme',
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => setState(() {}),
                          tooltip: 'Refresh',
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton.icon(
                          onPressed: () => _showEmergencyAlertDialog(),
                          icon: const Icon(Icons.warning),
                          label: const Text('Quick Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _getCurrentPage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_selectedMenuIndex) {
      case 0:
        return _dashboardBody();
      case 1:
        return _donorsBody();
      case 2:
        return _addEditBody();
      default:
        return _dashboardBody();
    }
  }
}