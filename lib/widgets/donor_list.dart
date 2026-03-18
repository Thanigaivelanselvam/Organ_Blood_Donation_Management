import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class DonorList extends StatelessWidget {
  const DonorList({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder(
      stream: service.getDonors(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];

            return ListTile(
              title: Text(d['name']),
              subtitle: Text(d['bloodGroup']),
            );
          },
        );
      },
    );
  }
}