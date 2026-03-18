import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'stat_card.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder(
      stream: service.getDonors(),
      builder: (context, snapshot) {
        final total = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatCard(title: "Total Donors", value: "$total", icon: Icons.people)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}