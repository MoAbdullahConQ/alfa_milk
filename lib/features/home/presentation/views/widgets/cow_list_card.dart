import 'package:flutter/material.dart';

import '../../../domain/entities/cow_list.dart';

/// The current cow-list card (US2). Shows count, last-updated time, and offers
/// an "Update Cow List" button that triggers the pick/load/save flow.
class CowListCard extends StatelessWidget {
  const CowListCard({super.key, this.cowList, required this.onUpdate});

  final CowList? cowList;
  final VoidCallback onUpdate;

  static String _formatDateTime(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} - '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final count = cowList?.cowNumbers.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Cow List',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(count == null
                ? 'No cow list imported yet.'
                : '$count cow(s) — last updated: ${_formatDateTime(cowList!.lastUpdated)}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.upload_file),
              label: const Text('Update Cow List'),
            ),
          ],
        ),
      ),
    );
  }
}
