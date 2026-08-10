import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/errors/custom_exceptions.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/helper_functions/error_dialog.dart';
import '../../../../../core/helper_functions/file_picker_helper.dart';
import '../../../../../core/helper_functions/show_conversion_summary.dart';
import '../../../../../core/helper_functions/show_missing_cows_dialog.dart';
import '../../../../home/domain/entities/alpro_report.dart';
import '../../../../home/domain/entities/cow_list.dart';
import '../../../../home/domain/use_cases/detect_missing_cows_use_case.dart';
import '../../../../home/domain/use_cases/filter_records_use_case.dart';
import '../../manager/conversion_cubit/conversion_cubit.dart';

/// The User Story 1 report-convert UI: select an Alpro HTML report and run the
/// conversion pipeline. The [CONVERT] handler runs a preview (parse + filter +
/// detect missing cows) and, when cows are missing, asks the user whether to
/// continue (US3, FR-010/FR-011/FR-021). It then always asks where to save the
/// output (US4, FR-015) and writes only to the chosen location (T019).
class ReportConvertView extends StatelessWidget {
  const ReportConvertView({
    super.key,
    required this.selectedHtmlPath,
    required this.activeCowList,
    required this.onSelectHtml,
  });

  final String? selectedHtmlPath;
  final CowList? activeCowList;
  final VoidCallback onSelectHtml;

  /// The [CONVERT] handler: guard, preview, missing-cow dialog, then save flow.
  Future<void> _convert(BuildContext context) async {
    final cubit = BlocProvider.of<ConversionCubit>(context);
    final htmlPath = selectedHtmlPath;
    final cowList = activeCowList;

    if (htmlPath == null) {
      showErrorDialog(
          context, 'Select an Alpro HTML report before converting.');
      return;
    }
    // No-cow-list guard (C1): reserved for *having no list*, and must not
    // fall through to the FR-021 zero-match message.
    if (cowList == null) {
      showErrorDialog(context, NoCowListError.instance.toString());
      return;
    }

    cubit.showLoading();

    // Preview: parse + filter + detect missing cows (no write).
    final parsed = await cubit.convertReportUseCase.conversionRepo
        .parseAlproReport(htmlPath);
    if (!context.mounted) {
      cubit.reset();
      return;
    }
    final preview = parsed.fold(
      (failure) {
        showErrorDialog(context, failure.message);
        cubit.reset();
        return null;
      },
      (report) => _preview(report, cowList),
    );
    if (preview == null) return; // parse error already shown + reset above

    // FR-021: having a list but matching nothing → explain, create NO file.
    if (preview.found == 0) {
      showErrorDialog(context,
          'No records matched the current cow list; nothing to export.');
      cubit.reset();
      return;
    }

    // FR-010/FR-011: missing cows → ask before exporting only the found ones.
    if (preview.missing.isNotEmpty) {
      final proceed = await showMissingCowsDialog(context, preview.missing);
      if (!proceed || !context.mounted) {
        // Cancel → no file created; re-enable CONVERT.
        cubit.reset();
        return;
      }
    }

    // US4 save flow (T019): the user picks the destination every time; the
    // source report is never used as the output path. On an output-write
    // failure (e.g. a locked/read-only location) we show a friendly message
    // and let the user pick again (FR-017).
    while (true) {
      final String? outputPath = await pickOutputXlsxPath();
      if (outputPath == null || !context.mounted) {
        // Cancelled the save dialog → no file; re-enable CONVERT.
        cubit.reset();
        return;
      }

      final result = await cubit.convert(
        alproHtmlPath: htmlPath,
        cowList: cowList,
        outputXlsxPath: outputPath,
      );
      if (!context.mounted) return;

      // Retry loop only on an output-write failure (FR-017).
      final writeFailure = result.fold<OutputWriteFailure?>(
        (f) => f is OutputWriteFailure ? f : null,
        (_) => null,
      );
      if (writeFailure != null) {
        showErrorDialog(context,
            'The DairySense file could not be saved to that location. '
                'Choose another folder and try again.');
        cubit.reset();
        continue; // re-open the save dialog
      }

      // Otherwise surface the outcome (friendly error or success summary).
      result.fold(
        (failure) {
          showErrorDialog(context, failure.message);
          cubit.reset();
        },
        (conversionResult) =>
            showConversionSummary(context, conversionResult),
      );
      return;
    }
  }

  /// Pure preview: which cows matched and which are missing (sorted ascending).
  ({int found, List<int> missing}) _preview(
      AlproReport report, CowList cowList) {
    final matched = FilterRecordsUseCase().call(
        report.records, cowList.cowNumbers);
    final missing = DetectMissingCowsUseCase().call(
      selected: cowList.cowNumbers,
      inReport: report.records.map((r) => r.cowNumber).toSet(),
    );
    return (found: matched.length, missing: missing);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Alpro Report',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            BlocBuilder<ConversionCubit, ConversionState>(
              builder: (context, state) {
                final busy = state is ConversionLoading;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : onSelectHtml,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Select HTML file'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedHtmlPath == null
                          ? 'No report selected.'
                          : selectedHtmlPath!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : () => _convert(context),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz),
                      label: const Text('CONVERT'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
