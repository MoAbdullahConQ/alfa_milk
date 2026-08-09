import 'package:flutter/material.dart';

import '../../../domain/entities/cow_list.dart';

/// The current cow-list card. Placeholder until US2 (T017) makes it
/// interactive and populated.
class CowListCard extends StatelessWidget {
  const CowListCard({super.key, this.cowList});

  final CowList? cowList;

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
                : '$count cow(s) — last updated: ${cowList!.lastUpdated}'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Update Cow List'),
            ),
          ],
        ),
      ),
    );
  }
}
