
import 'package:alfa_milk/features/home/domain/entities/conversion_result.dart';
import 'package:flutter/material.dart';

/// Render the post-conversion summary inside a dialog. Values are
/// selectable/copyable.
void showConversionSummary(
    BuildContext context, ConversionResult result) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Conversion complete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Report records', result.reportCount.toString()),
            _row('Cow list selected', result.selected.toString()),
            _row('Matched (found)', result.found.toString()),
            _row('Missing cows',
                result.missing.isEmpty ? 'None' : result.missing.join(', ')),
            if (result.warnings.isNotEmpty)
              _row('Warnings', result.warnings.join('; ')),
            if (result.outputPath != null)
              _row('Saved to', result.outputPath!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText('$label: $value'),
    );
