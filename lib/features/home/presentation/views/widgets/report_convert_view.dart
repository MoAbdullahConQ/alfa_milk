import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/helper_functions/error_dialog.dart';
import '../../../../../core/helper_functions/show_conversion_summary.dart';
import '../../manager/conversion_cubit/conversion_cubit.dart';

/// The User Story 1 report-convert UI: select an Alpro HTML report and run the
/// conversion pipeline. Reads busy/result/failure from the [ConversionCubit].
class ReportConvertView extends StatelessWidget {
  const ReportConvertView({
    super.key,
    required this.selectedHtmlPath,
    required this.onSelectHtml,
    required this.onConvert,
  });

  final String? selectedHtmlPath;
  final VoidCallback onSelectHtml;
  final VoidCallback onConvert;

  void _handleState(BuildContext context, ConversionState state) {
    if (state is ConversionSuccess) {
      showConversionSummary(context, state.conversionResult);
    } else if (state is ConversionFailure) {
      showErrorDialog(context, state.errMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocListener<ConversionCubit, ConversionState>(
          listener: _handleState,
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
                        onPressed: busy ? null : onConvert,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}
