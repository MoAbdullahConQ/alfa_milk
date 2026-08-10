import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/custom_exceptions.dart';
import '../../../../core/helper_functions/error_dialog.dart';
import '../../../../core/helper_functions/file_picker_helper.dart';
import '../../../../features/cow_list/data/cow_list_loader.dart';
import '../../../../features/cow_list/data/cow_list_store.dart';
import '../../data/repos/conversion_repo_impl.dart';
import '../../domain/entities/cow_list.dart';
import '../../domain/use_cases/convert_report_use_case.dart';
import '../manager/conversion_cubit/conversion_cubit.dart';
import 'widgets/cow_list_card.dart';
import 'widgets/report_convert_view.dart';

/// The single app shell. Owns the UI-local state (picked file, cow list) and
/// wires the [ConversionCubit] into the tree.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late final ConversionCubit _conversionCubit;
  final CowListStore _cowListStore = const CowListStore();

  String? selectedHtmlPath;
  CowList? activeCowList;

  @override
  void initState() {
    super.initState();
    _conversionCubit = ConversionCubit(
      convertReportUseCase: ConvertReportUseCase(ConversionRepoImpl()),
    );
    _restoreCowList();
  }

  @override
  void dispose() {
    _conversionCubit.close();
    super.dispose();
  }

  /// Auto-reuse the saved list after restart (FR-006/FR-007).
  Future<void> _restoreCowList() async {
    final saved = await _cowListStore.getCowListFile();
    if (mounted && saved != null) {
      setState(() => activeCowList = saved);
    }
  }

  Future<void> _selectHtml() async {
    final path = await pickHtmlFile();
    if (path != null) {
      setState(() => selectedHtmlPath = path);
    }
  }

  /// Pick an XLSX cow list, validate, persist, then refresh the card.
  /// On failure, keep the previous list (FR-008).
  Future<void> _updateCowList() async {
    final path = await pickCowListXlsx();
    if (path == null) return; // cancelled

    try {
      final result = CowListLoader().load(path);
      final newList = CowList(
        cowNumbers: result.cowNumbers.toSet(),
        lastUpdated: DateTime.now(),
      );
      await _cowListStore.saveCowList(newList);
      if (!mounted) return;
      setState(() => activeCowList = newList);

      var message =
          'Imported ${result.cowNumbers.length} cow(s).';
      if (result.usedFallback) {
        message +=
            '\nNo "Cow Number" column was detected, so the first numeric '
                'column was used instead. Please verify the list.';
      }
      if (result.warnings.isNotEmpty) {
        message += '\n${result.warnings.length} non-numeric value(s) skipped.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on CowListError catch (e) {
      if (mounted) showErrorDialog(context, e.toString());
    } catch (e) {
      if (mounted) showErrorDialog(context, 'The cow list could not be read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _conversionCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alfa → DairySense Converter'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CowListCard(cowList: activeCowList, onUpdate: _updateCowList),
              const SizedBox(height: 16),
              ReportConvertView(
                selectedHtmlPath: selectedHtmlPath,
                activeCowList: activeCowList,
                onSelectHtml: _selectHtml,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
