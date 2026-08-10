import 'package:flutter/material.dart';

/// Prompts the user when cows on the active list are absent from the report.
///
/// Returns `true` when the user chooses Continue (export only found cows) and
/// `false` on Cancel (abort, no file created — FR-011). The message is
/// selectable/copyable.
Future<bool> showMissingCowsDialog(
    BuildContext context, List<int> missing) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Missing cows'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: SingleChildScrollView(
          child: SelectableText(
            '${missing.length} cow(s) on your current list were not found in '
            'the report:\n\n${missing.join(', ')}\n\n'
            'Continue will export only the cows found in the report.',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
