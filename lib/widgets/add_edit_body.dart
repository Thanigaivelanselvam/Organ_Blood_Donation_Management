import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AddEditBody extends StatefulWidget {
  const AddEditBody({super.key});

  @override
  State<AddEditBody> createState() => _AddEditBodyState();
}

class _AddEditBodyState extends State<AddEditBody> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final blood = TextEditingController();

  final service = FirestoreService();

  void save() async {
    await service.addDonor({
      'name': name.text,
      'phone': phone.text,
      'bloodGroup': blood.text,
      'updatedAt': DateTime.now(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Saved")));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
          TextField(controller: phone, decoration: const InputDecoration(labelText: "Phone")),
          TextField(controller: blood, decoration: const InputDecoration(labelText: "Blood Group")),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: save, child: const Text("Save")),
        ],
      ),
    );
  }
}