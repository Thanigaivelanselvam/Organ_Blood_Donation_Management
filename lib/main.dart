// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';          // <-- NEW: for orientation
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';



Future<Null>? main() {
  return runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ---------- FORCE LANDSCAPE ONLY ----------
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // -----------------------------------------

    runApp(const ShareJoyApp());
  }, (error, stack) {
    print('Uncaught error: $error\n$stack');
  });
}

// ------------------------------------------------------------------
// NEW: Overlay shown when device is in portrait
// ------------------------------------------------------------------
class _ForceLandscapeWrapper extends StatelessWidget {
  final Widget child;

  const _ForceLandscapeWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return Scaffold(
            backgroundColor: Colors.black54,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_rotation, size: 64, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    'Please rotate your device to landscape',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
// ------------------------------------------------------------------

class ShareJoyApp extends StatefulWidget {
  const ShareJoyApp({Key? key}) : super(key: key);

  @override
  State<ShareJoyApp> createState() => _ShareJoyAppState();
}

class _ShareJoyAppState extends State<ShareJoyApp> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Share Joy — Donation Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _ForceLandscapeWrapper(
        child: DashboardPage(
          darkMode: _dark,
          onToggleTheme: () => setState(() => _dark = !_dark),
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final bool darkMode;
  final VoidCallback onToggleTheme;
  const DashboardPage({required this.darkMode, required this.onToggleTheme, Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CollectionReference donorsCol = FirebaseFirestore.instance.collection('donors');
  final CollectionReference alertsCol = FirebaseFirestore.instance.collection('alerts');

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donor added')));
      } else {
        await donorsCol.doc(_editingDocId).set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donor updated')));
      }
      _clearForm();
      setState(() => _selectedMenuIndex = 1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving donor: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteDonor(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Donor'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await donorsCol.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donor deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _startEditing(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    _editingDocId = doc.id;
    _nameC.text = (d['name'] ?? '').toString();
    _phoneC.text = (d['phone'] ?? '').toString();
    _cityC.text = (d['city'] ?? '').toString();
    _bloodC.text = (d['bloodGroup'] ?? '').toString();
    final organs = (d['organs'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? '';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert created (hook to FCM via Cloud Function)')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert failed: $e')));
    }
  }

  // Stats UI
  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(backgroundColor: Colors.red.shade100, child: Icon(icon, color: Colors.red.shade700)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ])
        ]),
      ),
    );
  }

  // Donors stream + local filters
  Widget _donorsList() {
    final stream = donorsCol.orderBy('updatedAt', descending: true).snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        // build cities cache
        final cities = docs.map((d) => (d['city'] ?? '').toString()).where((c) => c.isNotEmpty).toSet().toList();
        _citiesCache = ['All', ...cities];

        final s = _searchC.text.trim().toLowerCase();
        docs = docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final bg = (d['bloodGroup'] ?? '').toString().toUpperCase();
          final city = (d['city'] ?? '').toString();
          if (_filterBlood != 'All' && bg != _filterBlood) return false;
          if (_filterCity != 'All' && city != _filterCity) return false;
          if (s.isEmpty) return true;
          final hay = '${d['name'] ?? ''} ${d['phone'] ?? ''} ${city} ${bg} ${(d['organs'] as List<dynamic>?)?.join(' ') ?? ''}'.toLowerCase();
          return hay.contains(s);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('No donors match your search/filters.'));

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
            final organs = (d['organs'] as List<dynamic>?)?.map((e) => e.toString()).join(', ') ?? '-';
            final available = (d['available'] ?? true) == true;
            final updatedAt = d['updatedAt'] as Timestamp?;
            final createdAt = d['createdAt'] as Timestamp?;

            return ListTile(
              leading: CircleAvatar(child: Text(bg, style: const TextStyle(fontSize: 12))),
              title: Text(name),
              subtitle: Text('City: $city • Organs: $organs\nPhone: $phone\nAdded: ${_formatTimestamp(createdAt)}  •  Updated: ${_formatTimestamp(updatedAt)}'),
              isThreeLine: true,
              trailing: Wrap(spacing: 4, children: [
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _startEditing(doc)),
                IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete', onPressed: () => _deleteDonor(doc.id)),
                IconButton(
                  icon: Icon(available ? Icons.check_circle : Icons.remove_circle),
                  tooltip: 'Toggle Availability',
                  onPressed: () async {
                    try {
                      await donorsCol.doc(doc.id).update({'available': !available, 'updatedAt': FieldValue.serverTimestamp()});
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
                    }
                  },
                ),
              ]),
            );
          },
        );
      },
    );
  }

  // Sidebar & navigation
  int _selectedMenuIndex = 0; // 0 Dashboard, 1 Donors, 2 Add/Edit

  Widget _sidebar(bool isWide) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Share Joy', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Organ & Blood Donation', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 18),
        _navButton(icon: Icons.dashboard, label: 'Dashboard', index: 0),
        _navButton(icon: Icons.people, label: 'Donors', index: 1),
        _navButton(icon: Icons.person_add, label: _editingDocId.isEmpty ? 'Add Donor' : 'Edit Donor', index: 2),
        const Divider(),
        ListTile(
          leading: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
          title: const Text('Toggle Theme'),
          onTap: widget.onToggleTheme,
        ),
        ListTile(
          leading: const Icon(Icons.notification_important),
          title: const Text('Send Emergency Alert'),
          onTap: () async {
            final ctrl = TextEditingController();
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Emergency Alert'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Alert message')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
                ],
              ),
            );
            if (ok == true) {
              await _broadcastEmergencyAlert(ctrl.text.trim().isEmpty ? 'Emergency: Immediate donors needed' : ctrl.text.trim());
            }
          },
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Admin: Web', style: Theme.of(context).textTheme.bodySmall),
        )
      ]),
    );
  }

  Widget _navButton({required IconData icon, required String label, required int index}) {
    final selected = _selectedMenuIndex == index;
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.red : null),
      title: Text(label),
      selected: selected,
      onTap: () => setState(() => _selectedMenuIndex = index),
    );
  }

  Widget _dashboardBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Stats row
        StreamBuilder<QuerySnapshot>(
          stream: donorsCol.snapshots(),
          builder: (context, snap) {
            final total = snap.hasData ? snap.data!.docs.length : 0;
            final available = snap.hasData ? snap.data!.docs.where((d) => (d['available'] ?? true) == true).length : 0;
            final Map<String, int> counts = {};
            if (snap.hasData) {
              for (var d in snap.data!.docs) {
                final bg = (d['bloodGroup'] ?? 'Unknown').toString();
                counts[bg] = (counts[bg] ?? 0) + 1;
              }
            }
            return Row(children: [
              Expanded(child: _statCard('Total Donors', '$total', Icons.people)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Available Now', '$available', Icons.bloodtype)),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Top Blood Groups', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (counts.isEmpty) const Text('-'),
                      for (var e in counts.entries.take(4)) Text('${e.key}: ${e.value}'),
                    ]),
                  ),
                ),
              )
            ]);
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchC,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search donors by name, phone, organ, city...'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterBlood,
                items: ['All','A+','A-','B+','B-','AB+','AB-','O+','O-'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterCity,
                items: _citiesCache.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _filterCity = v ?? 'All'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _donorsList()),
      ]),
    );
  }

  Widget _donorsBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('Donors', style: Theme.of(context).textTheme.headlineSmall)),
          ElevatedButton.icon(onPressed: () { _clearForm(); setState(() => _selectedMenuIndex = 2); }, icon: const Icon(Icons.person_add), label: const Text('Add Donor')),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchC,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search donors...'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterBlood,
                items: ['All','A+','A-','B+','B-','AB+','AB-','O+','O-'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _filterBlood = v ?? 'All'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _donorsList()),
      ]),
    );
  }

  Widget _addEditBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_editingDocId.isEmpty ? 'Register New Donor' : 'Edit Donor', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameC, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phoneC, decoration: const InputDecoration(labelText: 'Phone number'), keyboardType: TextInputType.phone, validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone' : null),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _cityC, decoration: const InputDecoration(labelText: 'City'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _bloodC, decoration: const InputDecoration(labelText: 'Blood group (e.g. O+)'))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _organsC, decoration: const InputDecoration(labelText: 'Organs (comma separated, e.g. kidney, liver)')),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Available now:'),
                    const SizedBox(width: 8),
                    Switch(value: _available, onChanged: (v) => setState(() => _available = v)),
                    const Spacer(),
                    if (_loading) const CircularProgressIndicator(),
                    ElevatedButton.icon(onPressed: _addOrUpdateDonor, icon: const Icon(Icons.save), label: Text(_editingDocId.isEmpty ? 'Add Donor' : 'Update')),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () { _clearForm(); setState(() => _selectedMenuIndex = 1); }, child: const Text('Cancel')),
                  ]),
                ]),
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
    final isWide = MediaQuery.of(context).size.width > 1000;
    return Scaffold(
      body: Row(children: [
        if (isWide) _sidebar(isWide),
        Expanded(
          child: Column(children: [
            // Top bar
            Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(children: [
                if (!isWide)
                  IconButton(icon: const Icon(Icons.menu), onPressed: () => showModalBottomSheet(context: context, builder: (_) => _sidebar(isWide))),
                Text('Share Joy — Admin Dashboard', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () => _broadcastEmergencyAlert('Immediate donors required in nearby hospitals'), icon: const Icon(Icons.warning), label: const Text('Quick Alert')),
              ]),
            ),
            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: () {
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
                }(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}