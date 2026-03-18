import 'package:flutter/material.dart';
import 'donor_list.dart';

class DonorsBody extends StatelessWidget {
  const DonorsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: DonorList(),
    );
  }
}